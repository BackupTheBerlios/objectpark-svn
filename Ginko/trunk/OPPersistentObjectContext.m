//
//  OPPersistentObjectContext.m
//
//  Created by Dirk Theisen on 22.07.05.
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

- (id) objectRegisteredForOid: (OID) oid ofClass: (Class) poClass
/*" Returns a subclass of OPPersistentObject. "*/
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

- (void) willRevertObject: (OPPersistentObject*) object
{
	//[lock lock];
    [changedObjects removeObject: object];  
}

- (void) didRevertObject: (OPPersistentObject*) object
{
	//[lock unlock];
}

- (OID) newDatabaseObjectForObject: (OPPersistentObject*) object
{
	[db beginTransaction]; // transaction is committed on -saveChanges
	OID newOid = [db insertNewRowForClass: [object class]];
	NSAssert1(newOid, @"Unable to insert row for new object %@", object);
	[changedObjects addObject: object]; // make sure the values make it into the database
	return newOid;
}

- (id) objectForOid: (OID) oid ofClass: (Class) poClass
/*" Returns a subclass of OPPersistentObject. "*/
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
	if (oid) {
		result = [db attributesForRowId: [object oid] ofClass: [object class]];
		if (!result) {
			NSLog(@"Faulting problem: object with id %llu not in the database.", oid);
		}
	} else {
		result = [NSMutableDictionary dictionary];
	}
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
	[self revertChanges]; // just to be sure

	NSHashTableCallBacks htCallBacks = NSNonRetainedObjectHashCallBacks;
	htCallBacks.hash = &oidHash;
	htCallBacks.isEqual = &oidEqual;
    if (registeredObjects) NSFreeHashTable(registeredObjects);
    registeredObjects = NSCreateHashTable(htCallBacks, 1000);
    
    [changedObjects release];
    changedObjects = [[NSMutableSet alloc] init]; 
        
    [deletedObjects release];
    deletedObjects = [[NSMutableSet alloc] init];
	
	[db close];
	[db open];
	
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

- (NSSet*) changedObjects
{
	return changedObjects;
}

- (NSSet*) deletedObjects
{
	return deletedObjects;
}

/*
- (void) prepareSave
{
	// Call -willDelete on all deleted objects
	[lock lock];
	
	NSEnumerator* de = [deletedObjects objectEnumerator];

	NSMutableSet* allDeleted = deletedObjects;
	NSMutableSet* allChanged = changedObjects;
	deletedObjects = [[NSMutableSet alloc] init];
	changedObjects = [[NSMutableSet alloc] init];
	
	// The following might trigger faults, so we need to unlock:
	[lock unlock];
	id deletedObject;
	
	do {
	while (deletedObject = [de objectEnumerator]) {
		[deletedObject willDelete];
	}
	
	} while ([deletedObjects count]);
	
}
*/

- (void) saveChanges
/*" Central method. Writes all changes done to persistent objects to the database. Afterwards, those objects are no longer retained by the context. "*/
{
	[lock lock];
	[db beginTransaction];
	
	// do we need a local autoreleasepoool here?
	
	if ([changedObjects count]) {
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
	}	
	
	if ([deletedObjects count]) {
		NSEnumerator* coe = [deletedObjects objectEnumerator];
		OPPersistentObject* deletedObject;
		while (deletedObject = [coe nextObject]) {
			
			NSLog(@"Will honk %@", deletedObject);
			[db deleteRowOfClass: [deletedObject class] 
						   rowId: [deletedObject currentOid]];
			
			[changedObjects removeObject: deletedObject];
		}
		
		// Release all changed objects:
		[deletedObjects release]; deletedObjects = [[NSMutableSet alloc] init];
	}
	
	[db commitTransaction];
	[lock unlock];
}

- (void) deleteObject: (OPPersistentObject*) object
/*" Marks object for deletion on the next -saveChanges call. "*/
{
	[deletedObjects addObject: object];
	[changedObjects removeObject: object];
	[object willDelete];
}


- (void) revertChanges
{
	[lock lock];
	
	OPPersistentObject* changedObject;
	while (changedObject = [changedObjects anyObject]) {
		[changedObject revert]; // removes itself from changedObjects
	}
	
	[db rollBackTransaction]; // in case one is in progress
	
	[lock unlock];
}

- (void) dealloc
{
    [self reset];
    [super dealloc];
}

- (OPSQLiteConnection*) dbConnection
{
	return db;
}

- (OPPersistentObjectEnumerator*) objectEnumeratorForClass: (Class) poClass
													 where: (NSString*) clause
{
	return [[[OPPersistentObjectEnumerator alloc] initWithContext: self 
													  resultClass: poClass
													  whereClause: clause] autorelease];
}

@end

@implementation OPPersistentObjectEnumerator 


- (id) initWithContext: (OPPersistentObjectContext*) aContext
		   resultClass: (Class) poClass 
		   whereClause: (NSString*) clause
{
	if (self = [super init]) {
		NSString* queryString = [NSString stringWithFormat: ([clause length]>0 ? @"select ROWID from %@ where %@;" : @"select ROWID from %@;"), [poClass databaseTableName], clause];
		
		context     = [aContext retain];
		resultClass = poClass;
		
		//NSLog(@"Preparing statement for fetches: %@", queryString);
		sqlite3_prepare([[context dbConnection] database], [queryString UTF8String], -1, &statement, NULL);
		if (!statement) {
			NSLog(@"Error preparing statement: %@", [[context dbConnection] lastError]);
			[self autorelease];
			return nil;
		}
		NSLog(@"Created enum statement 0x%x for table %@", statement, [resultClass databaseTableName]);
	} 
	return self;
}

// "select ZMESSAGE.ROWID from ZMESSAGE, ZJOIN where aaa=bbb;"

- (void) bind: (id) variable, ...;
/*" Replaces all the question marks in the where string with the values passed.
	Current implementation only uses the first variable. "*/
{
	[variable bindValueToStatement: statement index: 1];
#warning todo: Implement vararg to support more than one variable binding.
}

/*
- (id) nextObject
//" Call this if you might not need the object and want to spare memory. "
{
	int res = sqlite3_step(statement);
}
*/

- (void) reset
{
	sqlite3_reset(statement);
}

- (id) nextObject
/*" Returns the next fetched object including all its attributes. "*/
{
	id result = nil;
	int res = sqlite3_step(statement);
	if (res==SQLITE_ROW) {
		if (NO && sqlite3_column_count(statement)>1) {
			// expect to fetch the whole attribute-set:
			assert(NO);
		} else {
			// expect the rowid on position one:
			ROWID rid = sqlite3_column_int64(statement, 0);
			result = [context objectForOid: rid ofClass: resultClass];
		}
	}
	return result;
}

- (void) dealloc
{
	sqlite3_finalize(statement);
	[context release]; context = nil;
	[super dealloc];
}

@end


NSURL* OPURLFromOidAndClass(OID oid, Class poClass)
{
#warning Axel, please modify this so it makes sense.
	return [NSURL URLWithString: [NSString stringWithFormat: @"opo://%@/%@/%lld", @"GinkoVoyager", poClass, oid]];
}


