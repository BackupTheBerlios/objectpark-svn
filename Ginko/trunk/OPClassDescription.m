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
//#import "OPAttributeDescription.h"
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
			[(ad->columnName ? attrs : relations) addObject: ad];
		}
		NSLog(@"Found relations in %@: %@", poClass, relations);
		NSLog(@"Found attributes in %@: %@", poClass, attrs);
		// relations are put at the end!
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
		if (attr->columnName) [result addObject: attr->columnName];
	}
	return result;
}

- (NSArray*) attributeNames
{
	NSMutableArray* result = [NSMutableArray array];
	NSEnumerator* e = [attributeDescriptions objectEnumerator];
	OPAttributeDescription* attr;
	while (attr = [e nextObject]) {
		[result addObject: attr->name];
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

- (void) createStatementsForConnection: (OPSQLiteConnection*) connection
{
	/*
    if (!fetchStatement) {
        NSString* queryString = [NSString stringWithFormat: @"select %@ from %@ where ROWID=?;", [[self columnNames] componentsJoinedByString: @","], [self tableName]];
        //NSLog(@"Preparing statement for fetches: %@", queryString);
        sqlite3_prepare([connection database], [queryString UTF8String], -1, &fetchStatement, NULL);
        if (!fetchStatement) NSLog(@"Error preparing statement '%@': %@", queryString, [connection lastError]);
        //NSLog(@"Created fetchStatement 0x%x for table %@", fetchStatement, [self tableName]);
    } 
	*/
	if (!insertStatement) {
		
		// Just create an empty entry to get a new ROWID:
		NSString* queryString = [NSString stringWithFormat: @"insert into %@ (ROWID) values (NULL);", [self tableName]];
		//NSLog(@"Preparing statement for inserts: %@", queryString);
        sqlite3_prepare([connection database], [queryString UTF8String], -1, &insertStatement, NULL);

		NSAssert2(insertStatement, @"Could not prepare statement (%@): %@", queryString, [connection lastError]);

	}
	
	/*
	if (!updateStatement) {
		
		NSMutableArray* columnNames = [self columnNames];
		int i = [columnNames count] + 1;
		NSMutableArray* valuePlaceholders = [NSMutableArray array];
		while (i--) [valuePlaceholders addObject: @"?"];
		[columnNames addObject: @"ROWID"];

		NSString* queryString = [NSString stringWithFormat: @"insert or replace into %@ (%@) values (%@);", [self tableName], [columnNames componentsJoinedByString: @","], [valuePlaceholders componentsJoinedByString: @","]];
		//NSLog(@"Preparing statement for updates: %@", queryString);
		sqlite3_prepare([connection database], [queryString UTF8String], -1, &updateStatement, NULL);

		NSAssert2(updateStatement, @"Could not prepare statement '%@': %@", queryString, [connection lastError]);

	}
	 */
	
	if (!deleteStatement) {
		
		NSString* queryString = [NSString stringWithFormat: @"delete from %@ where ROWID = ?;", [self tableName]];
		//NSLog(@"Preparing statement for deletes: %@", queryString);
        sqlite3_prepare([connection database], [queryString UTF8String], -1, &deleteStatement, NULL);
		
		NSAssert2(deleteStatement, @"Could not prepare statement (%@): %@", queryString, [connection lastError]);
	}
	
}

- (sqlite3_stmt*) insertStatement
{
	assert(insertStatement);

	sqlite3_reset(insertStatement);
	
	return insertStatement;
}

- (sqlite3_stmt*) deleteStatementForRowId: (ROWID) rid
{
	assert(deleteStatement);
	NSParameterAssert(rid>0);
	sqlite3_reset(deleteStatement);
	sqlite3_bind_int64(deleteStatement, 1, rid);

	return deleteStatement;
}


/*
- (sqlite3_stmt*) updateStatementForRowId: (ROWID) rid
{
	assert(updateStatement);
	
	sqlite3_reset(updateStatement);
	// The last placeholder is the ROWID:
	if (rid) {
		sqlite3_bind_int64(updateStatement, [attributeDescriptions count]+1, rid);
	} else {
		//NSLog(@"Binding to null rowid to request one...");
		sqlite3_bind_null(updateStatement,[attributeDescriptions count]+1);
	}
	
	return updateStatement;
}
*/


- (NSString*) tableName
{
	return [persistentClass databaseTableName];
}


- (void) dealloc
{
	if (deleteStatement) sqlite3_finalize(deleteStatement);
	if (insertStatement) sqlite3_finalize(insertStatement);
	[attributeDescriptions release];
	[super dealloc];
}

- (NSString*) description
{
	return [NSString stringWithFormat: @"<ClassDescription 0x%x for %@>", self, persistentClass];
}

@end

@implementation OPAttributeDescription

/*
- (id) initWithName: (NSString*) attributeName
		 columnName: (NSString*) dbName
		   andClass: (Class) aClass
{
	if (self = [super init]) {
		NSParameterAssert(attributeName!=nil);
		name       = [attributeName copy];
		columnName = [(dbName ? dbName : name) copy];
		theClass   = aClass ? aClass : [NSString class]; // attribute class defaults to string
		NSParameterAssert([aClass canPersist]);
	}
	return self;
}
*/

- (id) initWithName: (NSString*) aName properties: (NSDictionary*) dict
{
	NSParameterAssert(aName);
	if (self = [super init]) {
		
		name        = [aName copy];
		columnName  = [[dict objectForKey: @"ColumnName"] copy];
		theClass    = NSClassFromString([dict objectForKey: @"AttributeClass"]);
		queryString = [dict objectForKey: @"QueryString"];
		
		NSParameterAssert([theClass canPersist]);
		
	}
	
	return self;
}

- (NSString*) queryString
{
	return queryString;
}

- (Class) attributeClass
{
	return theClass;
}

- (NSString*) description
{
	return [NSString stringWithFormat: @"%@ name: %@", [super description], name];
}


/*
- (sqlite3_stmt*) fetchStatement
{
	if (!fetchStatement) {
		NSString* queryString = ;
        //NSLog(@"Preparing statement for fetches: %@", queryString);
        sqlite3_prepare([connection database], [queryString UTF8String], -1, &fetchStatement, NULL);
        if (!fetchStatement) NSLog(@"Error preparing statement: %@", [connection lastError]);
        //NSLog(@"Created fetchStatement 0x%x for table %@", fetchStatement, [self tableName]);
		
		
		fetchStatement = 
		
	}
	sqlite3_reset(fetchStatement);
	return fetchStatement;
}
*/

- (void) dealloc
{
	[name release];
	[columnName release];
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





