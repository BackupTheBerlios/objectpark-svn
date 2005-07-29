//
//  OPClassDescription.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 27.07.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include <sqlite3.h>
#import "OPPersistenceConstants.h"

@class OPSQLiteConnection;
@class OPPersistentObject;

@interface OPClassDescription : NSObject {
	@public
	Class persistentClass;
	NSArray* attributeDescriptions;
	NSString* columnList; // comma-separated list of column names
	NSString* tableName;
	
	sqlite3_stmt* insertStatement;
	sqlite3_stmt* deleteStatement;
	sqlite3_stmt* fetchStatement;
	sqlite3_stmt* updateStatement;
}

- (id) initWithPersistentClass: (Class) poClass;
- (void) createStatementsForConnection: (OPSQLiteConnection*) connection;
- (sqlite3_stmt*) fetchStatementForRowId: (ROWID) rid;
- (sqlite3_stmt*) insertStatement;
- (sqlite3_stmt*) updateStatement;


- (NSString*) tableName;


@end

#import <Cocoa/Cocoa.h>

@interface OPAttributeDescription : NSObject {
	@public // Made public for fast access only. Never change those. These objects are immutable.
	NSString* name;
	NSString* columnName;
	Class theClass; // The class to use for the attribute. Either NSString, NSNumber, NSData or NSDate or any OPPerstistentObject (subclass)
					// more stuff for relationships:
	Class targetClass; // for relationships
	NSString* foreignKeyColumnName; // for 1:n relationships 
	NSString* joinTableName;
}

- (id) initWithName: (NSString*) attributeName
		 columnName: (NSString*) dbName
		   andClass: (Class) aClass;

- (id) initWithName: (NSString*) aName properties: (NSDictionary*) dict;


@end

