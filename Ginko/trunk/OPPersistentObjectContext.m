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
	NSParameterAssert([object currentOid]>0); // hashing is based on oids here
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
    //NSLog(@"Object registered for oid %llu: %@", oid, result);
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

- (OID) newDatabaseObjectForObject: (OPPersistentObject*) object
{
	[db beginTransaction]; // transaction is committed on -saveChanges
	OID newOid = [db insertNewRowForClass: [object class]];
	NSAssert1(newOid, @"Unable to insert row for new object %@", object);
	[changedObjects addObject: object]; // make sure the values make it into the database
	return newOid;
}

- (OPPersistentObject*) objectForOid: (OID) oid
							 ofClass: (Class) poClass
{
	if (!oid) return nil;
    OPPersistentObject* result = [self objectRegisteredForOid: oid ofClass: poClass];
    // Look up in registered objects cache
    if (!result) { 
        // not found - create a fault object:
        result = [[[poClass alloc] initFaultWithContext: self oid: oid] autorelease];
		//NSLog(@"Registered object %@, lookup returns %@", result, [self objectRegisteredForOid: oid ofClass: poClass]);
        NSAssert(result == [self objectRegisteredForOid: oid ofClass: poClass], @"Problem with hash lookup");
    }
    return result;
}

- (NSDictionary*) persistentValuesForObject: (OPPersistentObject*) object
{
	OID oid = [object currentOid];
	id result = nil;
	if (oid) 
		result = [db attributesForOid: [object oid] ofClass: [object class]];
	else
		result = [NSMutableDictionary dictionary];
	return result;
}

static BOOL	oidEqual(NSHashTable* table, const void* object1, const void* object2)
{
	//NSLog(@"Comparing %@ and %@.", object1, object2);
	return [(OPPersistentObject*)object1 currentOid] == [(OPPersistentObject*)object2 currentOid] && [(OPPersistentObject*)object1 class]==[(OPPersistentObject*)object2 class];
}


static unsigned	oidHash(NSHashTable* table, const void * object)
/* Hash function used for the registered objects table, based on the object oid. 
 * Newly created objects do have a changing oid and so cannot be put into 
 * the registeredObjects hashTable.
 */
{
	// Maybe we need a better hash funktion as multiple tables will use the same oids.
	// Incorporate the class pointer somehow?
	unsigned result = (unsigned)[(OPPersistentObject*)object currentOid];
	return result;
}

- (void) reset
/*" Resets the internal state of the receiver, excluding the database connection. "*/
{
	NSHashTableCallBacks htCallBacks = NSNonRetainedObjectHashCallBacks;
	htCallBacks.hash = &oidHash;
	htCallBacks.isEqual = &oidEqual;
    if (registeredObjects) NSFreeHashTable(registeredObjects);
    registeredObjects = NSCreateHashTable(htCallBacks, 1000);
    
    [changedObjects release];
    changedObjects = [[NSMutableSet alloc] init]; 
        
    [deletedObjects release];
    deletedObjects = [[NSMutableSet alloc] init];
	
	[db rollBackTransaction]; // just to be sure
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
/*" Central method. Writes all changes done to persistent objects to the database. Afterwards, those objects are no longer retained by the context. "*/
{
	[db beginTransaction];
	
	NSLog(@"Saving %u object(s).", [changedObjects count]);

	// Process all updated objects and save their changed attribute sets:
	NSEnumerator* coe = [changedObjects objectEnumerator];
	OPPersistentObject* changedObject;
	while (changedObject = [coe nextObject]) {
		
		OID newOid = [db updateRowOfClass: [changedObject class] 
									rowId: [changedObject currentOid] 
								   values: [changedObject attributeValues]];
		
		[changedObject setOid: newOid]; // also registers object
		
	}
	
	// Release all changed objects:
	[changedObjects release]; changedObjects = [[NSMutableSet alloc] init];
	
#warning implement deletion
	
	coe = [deletedObjects objectEnumerator];
	OPPersistentObject* deletedObject;
	while (deletedObject = [coe nextObject]) {
		
		NSLog(@"Should honk %@", deletedObject);
		//[db updateRowOfClass: [changedObject class] 
		//			   rowId: [changedObject currentOid] 
		
		[deletedObject refault]; // also registers object
		
	}
	
	// Release all changed objects:
	[deletedObjects release]; deletedObjects = [[NSMutableSet alloc] init];
	
	
	[db commitTransaction];
}

- (void) revertChanges
{
#warning refault all known objects on revert.
	
	[db rollBackTransaction];
}

- (void) dealloc
{
    [self reset];
    [super dealloc];
}

@end




