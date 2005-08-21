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

@implementation OPClassDescription

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
		NSDictionary* plist = [NSPropertyListSerialization propertyListFromData: [[poClass persistentAttributesPlist] dataUsingEncoding: NSISOLatin1StringEncoding] mutabilityOption: NSPropertyListImmutable format: NULL errorDescription: &errors];
		
		NSAssert2(!errors, @"Malformed attributes plist in %@: %@", self, errors);
		
		if (![plist count]) NSLog(@"Warning! Persistent class without persistent attributes.");
		
		NSEnumerator* keyEnumerator = [plist keyEnumerator];
		NSMutableArray* attrs = [NSMutableArray array];
		NSMutableArray* relations = [NSMutableArray array];
		NSString* key;
		while (key = [keyEnumerator nextObject]) {
			OPAttributeDescription* ad = [[[OPAttributeDescription alloc] initWithName: key properties: [plist objectForKey: key]] autorelease];
			[([ad isRelationship] ? relations : attrs) addObject: ad];
		}
		//NSLog(@"Found relations in %@: %@", poClass, relations);
		//NSLog(@"Found attributes in %@: %@", poClass, attrs);
		// relations are put at the end!
		simpleAttributeCount = [attrs count];
		[attrs addObjectsFromArray: relations];
		attributeDescriptions = [attrs copy];
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
{
	// improve over linear search?
	int count = [attributeDescriptions count];
	int i;
	for (i=0; i<count; i++) {
		OPAttributeDescription* ad = [attributeDescriptions objectAtIndex: i];
		if ([ad->name isEqualToString: name]) return ad;
	}
	return nil;
}


- (NSString*) tableName
{
	return [persistentClass databaseTableName];
}


- (void) dealloc
{
	[attributeDescriptions release];
	[super dealloc];
}

- (NSString*) description
{
	return [NSString stringWithFormat: @"<ClassDescription 0x%x for %@>", self, persistentClass];
}

@end

@implementation OPAttributeDescription


- (id) initWithName: (NSString*) aName properties: (NSDictionary*) dict
{
	NSParameterAssert(aName);
	if (self = [super init]) {
		
		name              = [aName copy];
		columnName        = [[dict objectForKey: @"ColumnName"] copy];
		theClass          = NSClassFromString([dict objectForKey: @"AttributeClass"]);
		queryString       = [[dict objectForKey: @"QueryString"] copy];
		sortAttributeName = [[dict objectForKey: @"SortAttribute"] copy];
		
		NSParameterAssert([theClass canPersist]);
		
	}
	
	return self;
}

- (NSString*) queryString
{
	return queryString;
}

- (BOOL) isRelationship
{
	return queryString!=nil;
}

- (NSString*) sortAttributeName
/*" Returns the attribute name to sort a relationship by. If (for a relationship) no sortAttribute is specified, the relationship is not sorted and an NSSet is used. "*/
{
	return sortAttributeName;
}

- (Class) attributeClass
{
	return theClass;
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





