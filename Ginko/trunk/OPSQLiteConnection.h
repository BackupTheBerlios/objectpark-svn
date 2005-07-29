//
//  OPSQLiteConnection.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 22.07.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include <sqlite3.h>
#import "OPPersistenceConstants.h"

@class OPPersistentObject;

@interface OPSQLiteConnection : NSObject {
    
    sqlite3* connection;
    NSString* dbPath;
	NSMutableDictionary* classDescriptions;
	BOOL transactionInProgress;
}

- (sqlite3*) database;

- (id) initWithFile: (NSString*) inPath;

- (BOOL) open;
- (void) close;
- (NSString*) path;

- (void) beginTransaction;
- (void) commitTransaction;
- (void) rollBackTransaction;
- (ROWID) insertNewRowForClass: (Class) poClass;


- (int) lastErrorNumber;
- (NSString*) lastError;
- (void) performCommand: (NSString*) sql;

- (ROWID) updateRowOfClass: (Class) poClass
					 rowId: (ROWID) rid
					values: (NSDictionary*) values;

- (NSDictionary*) attributesForOid: (OID) oid
						   ofClass: (Class) persistentClass;

@end

@interface NSObject (OPSQLiteSupport)

+ (BOOL) canPersist;

+ (id) newFromStatement: (sqlite3_stmt*) statement index: (int) index;
- (void) bindValueToStatement: (sqlite3_stmt*)  statement index: (int) index;

@end
