//
//  OPClassDescription.m
//
//  Created by Dirk Theisen on 27.07.05.
//  Copyright 2005 Dirk Theisen <d.theisen@objectpark.org>. All rights reserved.
//
//
//  OPPersistence - a persistent object library for Cocoa.
//
//  For non-commercial use, you can redistribute this library and/or
//  modify it under the terms of the GNU Lesser General Public
//  License as published by the Free Software Foundation; either
//  version 2.1 of the License, or (at your option) any later version.
//
//  This library is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
//  Lesser General Public License for more details:
//
//  <http://www.gnu.org/copyleft/lesser.html#SEC1>
//
//  You should have received a copy of the GNU Lesser General Public
//  License along with this library; if not, write to the Free Software
//  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
//
//  For commercial use, commercial licenses and redistribution licenses
//  are available - including support - from the author,
//  Dirk Theisen <d.theisen@objectpark.org> for a reasonable fee.
//
//  DEFINITION Commercial use
//  This library is used commercially whenever the library or derivative work
//  is charged for more than the price for shipping and handling.
//

#import "OPClassDescription.h"
#import "OPSQLiteConnection.h"
#import "OPPersistentObject.h"


#define CLASSDESCRIPTION  OPL_DOMAIN  @"ClassDescription"
#define CONFIG            OPL_ASPECT  0x01


@implementation OPClassDescription

- (void) checkTableUsingConnection: (OPSQLiteConnection*) connection
	/*" Checks with the master table, if the database table corresponding to the receiver does exists in the current database. Uses the dataase property's create statements to create one, iass needed. "*/
{
	NSString* queryString = [NSString stringWithFormat: @"select * from sqlite_master where tbl_name like \"%@\";", tableName];
	OPSQLiteStatement* statement = [[OPSQLiteStatement alloc] initWithSQL: queryString 
																connection: connection];
	if ([statement execute] == SQLITE_ROW) {
		[statement release];
		return; // we found a table with a matching name - good enough for now.
	}
	[statement release];
	
	[connection beginTransaction];
	// Execute create statement(s) stored in the description:
	NSEnumerator* cse = [createStatements objectEnumerator];
	NSString* sqlString;
	while (sqlString = [cse nextObject]) {
		OPSQLiteStatement* create = [[[OPSQLiteStatement alloc] initWithSQL: sqlString 
																 connection: connection] autorelease];
		@try {
			[create execute];
		} @catch (id exception) {
			NSLog(@"Error: Unable to create table %@ using statements %@: %@", tableName, createStatements, exception);
		}
		[create reset];
	}
	[connection commitTransaction];
}

- (id) initWithPersistentClass: (Class) poClass
{
	if (self = [super init]) {
		
		if (poClass==nil) {
			[self autorelease];
			NSParameterAssert(poClass!=nil);
		}
		
		persistentClass = poClass;
				
		// Create attributeDescriptions from plist
		NSString* errors = nil;
		NSString* plistString = [poClass persistentAttributesPlist];
		NSDictionary* plist = [NSPropertyListSerialization propertyListFromData: [plistString dataUsingEncoding: NSISOLatin1StringEncoding] mutabilityOption: NSPropertyListImmutable format: NULL errorDescription: &errors];
		
		NSAssert3(!errors, @"Malformed attributes plist %@ in %@: %@", plistString, poClass, errors);
		
		if (![plist count]) NSLog(@"Warning! Persistent class without persistent attributes.");
		
		NSEnumerator* keyEnumerator = [plist keyEnumerator];
		NSMutableArray* attrs = [NSMutableArray array];
		NSMutableArray* relations = [NSMutableArray array];
		NSMutableDictionary* dict = [NSMutableDictionary dictionary];
		NSString* key;
		while (key = [keyEnumerator nextObject]) {
			OPAttributeDescription* ad;
			ad = [[OPAttributeDescription alloc] initWithParentClass: poClass 
																name: key 
														  properties: [plist objectForKey: key]];
			
			[([ad isToManyRelationship] ? relations : attrs) addObject: ad];
			[dict setObject: ad forKey: key];
			[ad release];
		}
		//NSLog(@"Found relations in %@: %@", poClass, relations);
		//NSLog(@"Found attributes in %@: %@", poClass, attrs);
		// relations are put at the end!
		simpleAttributeCount = [attrs count];
		[attrs addObjectsFromArray: relations];
		attributeDescriptions = [attrs copy];
		attributeDescriptionsByName = [dict copy];
		
		// databaseProperties
		
		plistString = [poClass databaseProperties];
		plist = [NSPropertyListSerialization propertyListFromData: [plistString dataUsingEncoding: NSISOLatin1StringEncoding] mutabilityOption: NSPropertyListImmutable format: NULL errorDescription: &errors];
		tableName = [[plist objectForKey: @"TableName"] copy];
		if (!tableName) 
			tableName = [NSStringFromClass(poClass) copy];
		
		createStatements = [[plist objectForKey: @"CreateStatements"] retain];
		if (createStatements) 
			NSAssert([createStatements isKindOfClass: [NSArray class]], @"Please supply an array for the 'CreateStatements' key.");
		
		cachesAllObjects = [[plist objectForKey: @"CacheAllObjects"] boolValue];
		OPDebugLog(CLASSDESCRIPTION, CONFIG, @"%@: %d", self, cachesAllObjects);
		
	}
	return self;
}


- (NSMutableArray*) columnNames
{
	NSMutableArray* result = [NSMutableArray array];
	NSEnumerator* e = [attributeDescriptions objectEnumerator];
	OPAttributeDescription* attr;
	while (attr = [e nextObject]) {
		if (attr->columnName && !attr->queryString) [result addObject: attr->columnName];
	}
	return result;
}


- (OPAttributeDescription*) attributeWithName: (NSString*) name
/*" Returns the persistent attribute with the name given, or nil, if no such attribute exists. "*/
{
	if (name) {
		// improve over linear search?
		int count = [attributeDescriptions count];
		int i;
		for (i=0; i<count; i++) {
			OPAttributeDescription* ad = [attributeDescriptions objectAtIndex: i];
			if ([ad->name isEqualToString: name]) return ad;
		}
	}
	return nil;
}


- (NSString*) tableName
{
	return tableName;
}


- (void) dealloc
{
	[attributeDescriptions release];
	[tableName release];
	[createStatements release];
	[super dealloc];
}

- (NSString*) description
{
	return [NSString stringWithFormat: @"<ClassDescription 0x%x for %@>", self, persistentClass];
}

@end

@implementation OPAttributeDescription


- (id) initWithParentClass: (Class) poClass 
					  name: (NSString*) aName 
				properties: (NSDictionary*) dict
{
	NSParameterAssert(aName);
	if (self = [super init]) {
		
		name              = [aName copy];
		columnName        = [[dict objectForKey: @"ColumnName"] copy];
		theClass          = NSClassFromString([dict objectForKey: @"AttributeClass"]);
		queryString       = [[dict objectForKey: @"QueryString"] copy];
		sortAttributeName = [[dict objectForKey: @"SortAttribute"] copy];
		inverseRelationshipKey = [[dict objectForKey: @"InverseRelationshipKey"] copy];
		joinTableName     = [[dict objectForKey: @"JoinTableName"] copy];
		sourceColumnName  = [[dict objectForKey: @"SourceColumnName"] copy];
		targetColumnName  = [[dict objectForKey: @"TargetColumnName"] copy];
		
		if (joinTableName) {
			NSAssert2(sourceColumnName, @"Many-to-many relationships (like %@) need to specify a source column name for %@ using the SourceColumnName key.", name, joinTableName);
			NSAssert2(targetColumnName, @"Many-to-many relationships (like %@) need to specify a target column name for %@ using the TargetColumnName key.", name, joinTableName);
		}
		
		NSParameterAssert([theClass canPersist]);
		
        /*
		if ([name isEqualToString: @"messages"]) {
			NSLog(@"messages relation found");
		}
		*/
        
		if ([self isToManyRelationship]) {
			// See, if we have custom methods to add and remove values:
			
			// Build an search for remover selector:
			char addselstr[200] = "addTo";
			[name getCString: addselstr+5 maxLength: 190];
			addselstr[5] = toupper(addselstr[5]);
			strcat(addselstr, ":");
			SEL addsel = NSSelectorFromString([NSString stringWithCString: addselstr]);
			if ([poClass instancesRespondToSelector: addsel]) 
				valueAdder = addsel;
			
			// Build an search for remover selector:
			char remselstr[200] = "removeFrom";
			[name getCString: remselstr+10 maxLength: 190];
			remselstr[10] = toupper(remselstr[10]);
			strcat(remselstr, ":");
			SEL remsel = NSSelectorFromString([NSString stringWithCString: remselstr]);
			if ([poClass instancesRespondToSelector: remsel]) 
				valueRemover = remsel;
		}
	}
	
	return self;
}

- (NSString*) name
{
	return name;
}

- (NSString*) queryString
/*" Usually, querystrings are only set on to-many-relationships. They contain an SQL statement string "*/
{
	return queryString;
}

- (BOOL) isToManyRelationship
/*" Returns wether the attribute is a to-many-relationship. "*/
{
	// Bad criteria?
	return queryString!=nil;
}


- (NSString*) inverseRelationshipKey
/*" The key pointing back to (a relationship) containing self. "*/
{
	return inverseRelationshipKey;
}


- (NSString*) joinTableName
/*" Returns the name of the join table in case this is a many-to-many relationship, nil otherweise. "*/
{
	return joinTableName;
}

- (NSString*) sortAttributeName
/*" Returns the attribute name to sort a relationship by. If (for a relationship) no sortAttribute is specified, the relationship is not sorted. "*/
{
	return sortAttributeName;
}

- (NSString*) columnName
{
	return columnName;
}

- (Class) attributeClass
{
	return theClass;
}

- (NSString*) sourceColumnName
{
	return sourceColumnName;
}

- (NSString*) targetColumnName
{
	return targetColumnName;
}

- (SEL) valueAdder
{
	return valueAdder;
}

- (SEL) valueRemover
{
	return valueRemover;
}

- (OPAttributeDescription*) inverseRelationshipAttribute
/*" Returns the attribute for the inverse relationship of the receiver, if one exists. nil otherwise. "*/
{
	return [[[self attributeClass] persistentClassDescription] attributeWithName: [self inverseRelationshipKey]];
}

- (NSString*) description
{
	return [NSString stringWithFormat: @"%@ name: %@", [super description], name];
}

- (void) dealloc
{
	[name release];
	[columnName release];
	[queryString release];
	[joinTableName release];
	//sqlite3_finalize(fetchStatement);
	[super dealloc];
}


@end

@implementation NSObject (OPClassDescription)

+ (OPClassDescription*) persistentClassDescription
/*" Default implementation returns nil. e.g. OPPersistentObject implements this. "*/
{
	return nil;
}

@end





