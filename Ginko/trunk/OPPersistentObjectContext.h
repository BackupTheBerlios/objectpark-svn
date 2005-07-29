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

- (OPPersistentObject*) objectRegisteredForOid: (OID) oid
									   ofClass: (Class) poClass;
- (OPPersistentObject*) objectForOid: (OID) oid
							 ofClass: (Class) poClass;
- (void) registerObject: (OPPersistentObject*) object;
- (void) unregisterObject: (OPPersistentObject*) object;
- (NSSet*) changedObjects;
- (NSDictionary*) persistentValuesForObject: (OPPersistentObject*) object;
- (OID) newDatabaseObjectForObject: (OPPersistentObject*) object;


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

- (void) saveChanges;


@end
