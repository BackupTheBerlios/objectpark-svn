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

@interface OPSQLiteConnection : NSObject {
    
    sqlite3* connection;
    NSString* dbPath;
}

- (sqlite3*) database;
- (id) initWithFile: (NSString*) inPath;

- (NSDictionary*) attributeDictForTable: (NSString*) tableName
                             attributes: (NSArray*) attrNames
                                   keys: (NSArray*) keys
                                    oid: (OID) oid;

- (BOOL) open;
- (void) close;
- (NSString*) path;
- (unsigned long long) lastInsertedRowId;

- (void) beginTransaction;
- (void) commitTransaction;
- (void) rollBackTransaction;

- (int) lastErrorNumber;
- (NSString*) lastError;


@end
