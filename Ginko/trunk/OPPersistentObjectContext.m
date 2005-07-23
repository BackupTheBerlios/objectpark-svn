//
//  OPPersistentObjectContext.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 22.07.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "OPPersistentObjectContext.h"
#import "OPPersistentObject.h"
#import "OPSQLiteConnection.h"

@implementation OPPersistentObjectContext

static OPPersistentObjectContext* defaultContext = nil;

+ (OPPersistentObjectContext*) defaultContext
{
    return defaultContext;
}


// persistentClasses array associates a persistent class with its compact class id (cid).
static NSMutableArray* persistentClasses = nil;

+ (Class) classForCid: (CID) cid
{
    return [persistentClasses objectAtIndex: cid];
}

+ (CID) cidForClass: (Class) pClass
{
    if (!persistentClasses) {
        persistentClasses = [[NSMutableArray alloc] init];   
    }
    CID result = [persistentClasses indexOfObjectIdenticalTo: pClass];
    if (result == NSNotFound) {
        // Register class:
        result = [persistentClasses count];
        [persistentClasses addObject: pClass];
        NSLog(@"Assigning cid %d to class %@", result, pClass);
    }
    return result;
}

+ (void) setDefaultContext: (OPPersistentObjectContext*) context
/*" A default context can only be set once. It is retained and never deallocated. Use -reset to trim memory usage after no persistent objects are us use any more. "*/
{
    NSAssert(defaultContext==nil || defaultContext==context, @"Default context can only be set once.");
    
    if (context!=defaultContext) {
        defaultContext = [context retain];
    }
}

- (void) lock
{
    [lock lock];
}

- (void) unlock
{
    [lock lock];
}

- (NSDictionary*) persistentValuesForOid: (OID) oid
{
    Class poClass = [[self class] classForCid: (CIDFromOID(oid))];
    NSDictionary* attrDict = [db attributeDictForTable: [poClass databaseTableName]
                                            attributes: [poClass databaseAttributeNames]
                                                  keys: [poClass objectAttributeNames]
                                                   oid: LIDFromOID(oid)];
    
    return attrDict;
}



- (void) registerObject: (OPPersistentObject*) object
{
    NSHashInsert(registeredObjects, object);
}

- (void) unregisterObject: (OPPersistentObject*) object
/*" Called by -[OPPersistentObject dealloc] to make sure we do not keep references to stale objects. "*/
{
    NSHashRemove(registeredObjects, object);
}

- (void) willChangeObject: (OPPersistentObject*) object
/*" This method retains object until changes are saved. "*/
{
    [lock lock];
    [changedObjects addObject: object];  
}

- (void) didChangeObject: (OPPersistentObject*) object
{
    [lock unlock];
}

- (OPPersistentObject*) objectForOid: (OID) oid
{
    Class poClass = [[self class] classForCid: (CIDFromOID(oid))];
    OPPersistentObject* result = nil;
    // Look up in registered objects cache
    if (NO) { 
        // not found - create a fault object:
        result = [[[poClass alloc] initWithContext: self oid: oid] autorelease];
        [self registerObject: result];
    }
    return result;
}

- (void) reset
{
    if (registeredObjects) NSFreeHashTable(registeredObjects);
    registeredObjects = NSCreateHashTable(NSNonRetainedObjectHashCallBacks, 1000);
    
    [changedObjects release];
    changedObjects = [[NSMutableSet alloc] init]; 
    
    [insertedObjects release];
    insertedObjects = [[NSMutableSet alloc] init];    
    
    [deletedObjects release];
    deletedObjects = [[NSMutableSet alloc] init];
}

- (id) init 
{
    if (self = [super init]) {
        [self reset];        
    }
    return self;
}

- (NSArray*) fetchAllInstancesOfClass: (Class) persistentClass
{
    
}

- (void) dealloc
{
    [self reset];
    [super dealloc];
}

@end
