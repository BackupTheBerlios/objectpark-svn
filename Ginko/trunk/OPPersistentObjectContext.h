//
//  OPPersistentObjectContext.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 22.07.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include <sqlite3.h>
#import "OPPersistenceConstants.h"

@class OPPersistentObject;
@class OPSQLiteConnection;

@interface OPPersistentObjectContext : NSObject {
    
    NSHashTable* registeredObjects;
    NSMutableSet* changedObjects;
    NSMutableSet* insertedObjects;
    NSMutableSet* deletedObjects;
    NSRecursiveLock* lock; // unused so far
    
    OPSQLiteConnection* db;
}

// Methods for internal use:

+ (Class) classForCid: (CID) cid;
+ (CID) cidForClass: (Class) pClass;
+ (OID) oidForLid: (LID) lid class: (Class) poClass;

- (OPPersistentObject*) objectRegisteredForOid: (OID) oid;
- (OPPersistentObject*) objectForOid: (OID) oid;
- (void) registerObject: (OPPersistentObject*) object;
- (void) unregisterObject: (OPPersistentObject*) object;
- (NSDictionary*) persistentValuesForOid: (OID) oid;
+ (void) setDefaultContext: (OPPersistentObjectContext*) context;


- (void) setDatabaseConnectionFromPath: (NSString*) dbPath;
- (OPSQLiteConnection*) databaseConnection;
- (void) setDatabaseConnection: (OPSQLiteConnection*) newConnection;

// Methods for use by the appication developer:
+ (OPPersistentObjectContext*) defaultContext;
- (void) reset;

- (void) lock;
- (void) unlock;

- (void) willChangeObject: (OPPersistentObject*) object;
- (void) didChangeObject: (OPPersistentObject*) object;

@end