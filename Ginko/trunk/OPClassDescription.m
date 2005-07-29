//
//  OPClassDescription.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 27.07.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "OPClassDescription.h"
//#import "OPAttributeDescription.h"
#import "OPSQLiteConnection.h"
#import "OPPersistentObject.h"

@implementation OPClassDescription

- (id) initWithPersistentClass: (Class) poClass
{
	if (self = [super init]) {
		
		persistentClass = poClass;
				
		// Create attributeDescriptions from plist
		NSString* errors = nil;
		NSDictionary* plist = [NSPropertyListSerialization propertyListFromData: [[poClass persistentAttributesPlist] dataUsingEncoding: NSISOLatin1StringEncoding] mutabilityOption: NSPropertyListImmutable format: NULL errorDescription: &errors];
		
		NSAssert2(!errors, @"Malformed attributes plist in %@: %@", self, errors);
		
		if (![plist count]) NSLog(@"Warning! Persistent class without persistent attributes.");
		
		NSEnumerator* keyEnumerator = [plist keyEnumerator];
		NSMutableArray* attrs = [NSMutableArray array];
		NSString* key;
		while (key = [keyEnumerator nextObject]) {
			OPAttributeDescription* ad = [[[OPAttributeDescription alloc] initWithName: key properties: [plist objectForKey: key]] autorelease];
			[attrs addObject: ad];
		}
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
		[result addObject: attr->columnName];
	}
	return result;
}

- (void) createStatementsForConnection: (OPSQLiteConnection*) connection
{
    if (!fetchStatement) {
        NSString* queryString = [NSString stringWithFormat: @"select %@ from %@ where ROWID=?;", [[self columnNames] componentsJoinedByString: @","], [self tableName]];
        NSLog(@"Preparing statement for fetches: %@", queryString);
        sqlite3_prepare([connection database], [queryString UTF8String], -1, &fetchStatement, NULL);
        if (!fetchStatement) NSLog(@"Error preparing statement: %@", [connection lastError]);
        //NSLog(@"Created fetchStatement 0x%x for table %@", fetchStatement, [self tableName]);
    } 
	
	if (!insertStatement) {
		
		// Just create an empty entry to get a new ROWID:
		NSString* queryString = [NSString stringWithFormat: @"insert into %@ (ROWID) values (NULL);", [self tableName]];
		NSLog(@"Preparing statement for inserts: %@", queryString);
        sqlite3_prepare([connection database], [queryString UTF8String], -1, &insertStatement, NULL);

		NSAssert2(insertStatement, @"Could not prepare statement (%@): %@", queryString, [connection lastError]);

	}
	
	if (!updateStatement) {
		
		int i = [attributeDescriptions count] + 1;
		NSMutableArray* valuePlaceholders = [NSMutableArray array];
		while (i--) [valuePlaceholders addObject: @"?"];
		NSMutableArray* columnNames = [self columnNames];
		[columnNames addObject: @"ROWID"];

		NSString* queryString = [NSString stringWithFormat: @"insert or replace into %@ (%@) values (%@);", [self tableName], [columnNames componentsJoinedByString: @","], [valuePlaceholders componentsJoinedByString: @","]];
		NSLog(@"Preparing statement for updates: %@", queryString);
		sqlite3_prepare([connection database], [queryString UTF8String], -1, &updateStatement, NULL);

		NSAssert2(updateStatement, @"Could not prepare statement (%@): %@", queryString, [connection lastError]);

	}
	
	
}

- (sqlite3_stmt*) insertStatement
{
	assert(insertStatement);

	sqlite3_reset(insertStatement);
	
	return insertStatement;
}

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



- (sqlite3_stmt*) deleteStatementForRowId: (ROWID) rid
{
	assert(deleteStatement);
	
	sqlite3_reset(insertStatement);
	sqlite3_bind_int64(fetchStatement, 1, rid);	
	
	return deleteStatement;
}

- (NSString*) tableName
{
	return [persistentClass databaseTableName];
}

- (sqlite3_stmt*) fetchStatementForRowId: (ROWID) rid
{
	assert(fetchStatement);
	
	sqlite3_reset(fetchStatement);
    sqlite3_bind_int64(fetchStatement, 1, rid);	
	
	return fetchStatement;
}

- (void) dealloc
{
	if (deleteStatement) sqlite3_finalize(deleteStatement);
	if (insertStatement) sqlite3_finalize(insertStatement);
	if (fetchStatement) sqlite3_finalize(fetchStatement);
	[attributeDescriptions release];
	[super dealloc];
}

- (NSString*) description
{
	return [NSString stringWithFormat: @"<ClassDescription 0x%x for %@>", self, persistentClass];
}

@end

@implementation OPAttributeDescription

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

- (id) initWithName: (NSString*) aName properties: (NSDictionary*) dict
{
	id aColumnName = [dict objectForKey: @"ColumnName"];
	Class aClass = NSClassFromString([dict objectForKey: @"AttributeClass"]);
	
	return [self initWithName: aName columnName: aColumnName andClass: aClass];
}

- (void) dealloc
{
	[name release];
	[columnName release];
	[super dealloc];
}


@end

