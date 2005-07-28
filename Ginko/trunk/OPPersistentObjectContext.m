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
    if (!defaultContext) {
        [self setDefaultContext: [[[self alloc] init] autorelease]];
        NSLog(@"Created default %@", defaultContext);
    }
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

+ (OID) oidForLid: (LID) lid class: (Class) poClass
{
    return MakeOID([self cidForClass: poClass], lid);
}

+ (void) setDefaultContext: (OPPersistentObjectContext*) context
/*" A default context can only be set once. Use -reset to trim memory usage after no persistent objects are us use any more. "*/
{
    NSAssert(context == nil || defaultContext==nil || defaultContext==context, @"Default context can not be changed.");
    
    if (context!=defaultContext) {
        [defaultContext release];
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



- (void) registerObject: (OPPersistentObject*) object
{
    NSHashInsert(registeredObjects, object);
}

- (void) unregisterObject: (OPPersistentObject*) object
/*" Called by -[OPPersistentObject dealloc] to make sure we do not keep references to stale objects. "*/
{
    NSHashRemove(registeredObjects, object);
}

- (OPPersistentObject*) objectRegisteredForOid: (OID) oid
									   ofClass: (Class) poClass
{
    // SearchStruct is a fake object made for searching in the hashtable:
    struct {
        Class isa;
        OID oid;
        NSMutableDictionary* attributes;
    } searchStruct;
    searchStruct.isa = poClass;
    searchStruct.oid = oid;
    searchStruct.attributes = nil;

   //OPPersistentObject* testObject = [[[OPPersistentObject alloc] initWithContext: self oid: oid] autorelease];
    
    OPPersistentObject* result = NSHashGet(registeredObjects, &searchStruct);
    NSLog(@"Object registered for oid %llu: %@", oid, result);
    return result;
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
							 ofClass: (Class) poClass
{
    OPPersistentObject* result = [self objectRegisteredForOid: oid ofClass: poClass];
    // Look up in registered objects cache
    if (!result) { 
        // not found - create a fault object:
        result = [[[poClass alloc] initWithContext: self oid: oid] autorelease];
        [self registerObject: result];
        NSAssert(result == [self objectRegisteredForOid: oid ofClass: poClass], @"Problem with hash lookup");
    }
    return result;
}

- (NSDictionary*) persistentValuesForObject: (OPPersistentObject*) object
{
	return [db attributesForOid: [object oid] ofClass: [object class]];
}

- (void) reset
/*" Resets the internal state of the receiver, excluding the database connection. "*/
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

- (void) setDatabaseConnectionFromPath: (NSString*) dbPath
{
    OPSQLiteConnection* dbc = [[[OPSQLiteConnection alloc] initWithFile: dbPath] autorelease];
    [self setDatabaseConnection: dbc];
}
 
- (OPSQLiteConnection*) databaseConnection
{
    return db;   
}

- (void) setDatabaseConnection: (OPSQLiteConnection*) newConnection
{
    NSParameterAssert(db==nil);
    db = [newConnection retain];
    NSParameterAssert([db open]);
}

- (NSArray*) fetchAllInstancesOfClass: (Class) persistentClass
{
    // implement
    return nil;
}

- (NSSet*) changedObjects
{
	return changedObjects;
}



- (void) saveChanges
{
	[db beginTransaction];
	
	// Process all updated objects and save their changed attribute sets:
	NSEnumerator* coe = [changedObjects objectEnumerator];
	OPPersistentObject* changedObject;
	while (changedObject = [coe nextObject]) {
		
		[db updateObject: changedObject];
			
	}
	
	[db commitTransaction];
}

- (void) dealloc
{
    [self reset];
    [super dealloc];
}

@end




