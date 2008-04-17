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
//#import "OPClassDescription.h"
//#import "OPFaultingArray.h"
//#import "NSString+Extensions.h"
#import <Foundation/NSDebug.h>
//#import <OPObjectPair.h>
#import "OPKeyedArchiver.h"
#import "OPKeyedUnarchiver.h"
#import "OPDBLite.h"

/*
@interface OPPersistentObjectEnumerator : NSEnumerator {
	sqlite3_stmt* statement;
	Class resultClass;
	OPPersistentObjectContext* context;
}

- (id) initWithContext: (OPPersistentObjectContext*) aContext
		   resultClass: (Class) poClass 
		   queryString: (NSString*) sql;

- (id) initWithContext: (OPPersistentObjectContext*) aContext
		   resultClass: (Class) poClass 
		   whereClause: (NSString*) clause;

- (void) reset;
- (BOOL) skipObject;
- (sqlite3_stmt*) statement;
+ (void) printAllRunningEnumerators;
- (OPFaultingArray*) allObjectsSortedByKey: (NSString*) sortKey ofClass: (Class) sortKeyClass;

@end

*/

@implementation NSNumber (OPPerstistenceAdditions)

+ (NSNumber *)numberWithOID:(OID)anOid
{
	return [NSNumber numberWithUnsignedLongLong:anOid];
}

- (OID)OIDValue
{
	return (OID)[self unsignedLongLongValue];
}

@end

// Special oids:
#define CLASSTABLEOID 1 // cid 0, lid 1 
#define ROOTOBJECTSOID 2 // cid 0, lid 2 

@implementation OPPersistentObjectContext

static long long OPLongLongStringValueBase16(NSString* self)
{
	char buffer[100];
	NSUInteger usedLength = 0;
	[self getBytes:buffer maxLength:99 usedLength:&usedLength encoding:NSISOLatin1StringEncoding options:NSStringEncodingConversionAllowLossy range:NSMakeRange(0,[self length]) remainingRange:NULL];
	buffer[usedLength] = '\0'; // terminate
	return strtoll(buffer, (char **)NULL, 16);	
}

static LID OPLongStringValueBase16(NSString* self)
{
	char buffer[100];
	NSUInteger usedLength = 0;
	[self getBytes: buffer maxLength: 99 usedLength: &usedLength encoding: NSISOLatin1StringEncoding options: NSStringEncodingConversionAllowLossy range: NSMakeRange(0,[self length]) remainingRange: NULL];
	buffer[usedLength] = '\0'; // terminate
	return strtol(buffer, (char **)NULL, 16);	
}


static OPPersistentObjectContext* defaultContext = nil;

+ (OPPersistentObjectContext*) defaultContext
{
    return defaultContext;
}

+ (void) setDefaultContext: (OPPersistentObjectContext*) context
/*" A default context can only be set once. Use -reset to trim memory usage after no persistent objects are in use any more. "*/
{
    NSAssert(context == nil || defaultContext==nil || defaultContext==context, @"Default context can not be changed.");
    
    if (context!=defaultContext) {
        id oldContext = defaultContext;
        defaultContext = [context retain];
		[oldContext release]; // important after the assingment due to timing
    }
}

- (NSDictionary*) allObjectsByClass
/*" Returns a dictionary of NSMutableSets keyed by class(forCoder) name. Only objects of classes which -cachesAllObjects are recorded here. "*/
{
	return allObjectsByClass;
}

- (NSSet*) allObjectsOfClass: (Class) aClass
/*" Returns a set of all persistent, known instances of a class at a time. Objects never stored nor set as a persistent property of another persistent object might not appear here. Call -oid to force this. "*/
{
	NSAssert1([aClass cachesAllObjects], @"- allObjects may only be called with +[%@ cachesAllObjects] returning YES.", aClass);
	NSMutableSet* result = [allObjectsByClass objectForKey: [aClass description]];
	return result;
}

- (void) cacheObject: (NSObject<OPPersisting>*) object
{
	NSString* className = [[object classForCoder] description];
	NSMutableSet* cache = [allObjectsByClass objectForKey: className];
	if (! cache) {
		// create cache set on demand:
		cache = [NSMutableSet set];
		[allObjectsByClass setObject: cache forKey: className];
		[allObjectsByClass addObserver: self forKeyPath: className
				  options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld 
				  context: allObjectsByClass];
	}
	
	[cache addObject: object]; // should trigger a notification!
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == allObjectsByClass) {
		int changeKind = [[change objectForKey: NSKeyValueChangeKindKey] intValue];
		NSSet* removed = nil;
		NSSet* added = nil;
		if (changeKind == NSKeyValueChangeRemoval) {
			// Removals from this set trigger a deletion:
			removed = [change objectForKey: NSKeyValueChangeOldKey];
		} else if (changeKind == NSKeyValueChangeInsertion) {
			added = [change objectForKey: NSKeyValueChangeNewKey];
		} else if (changeKind == NSKeyValueChangeSetting) {
			// Why do we get this kind from an NSArrayController on insertion/deletion?
			removed = [[[change objectForKey: NSKeyValueChangeOldKey] mutableCopy] autorelease];
			[(NSMutableSet*)removed minusSet: [change objectForKey: NSKeyValueChangeNewKey]];
			added = [change objectForKey: NSKeyValueChangeNewKey]; // [[[change objectForKey: NSKeyValueChangeNewKey] mutableCopy] autorelease];
			//[(NSMutableSet*)added minusSet: [change objectForKey: NSKeyValueChangeOldKey]]; // does not work old and new set yield same elements on addition :-/ 
		}
		
		[removed makeObjectsPerformSelector: @selector(delete)]; // deletes from the database
		for (id object in added) {
			[self insertObject: object];
		}
		NSLog(@"allObjects changed: %@\ndeleted: %@\ninserted:%@", keyPath, removed, added);
	} else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

// SearchStruct is a fake object made for searching in the hashtable:
typedef struct {
	Class isa;
	OID oid;
} FakeObject;

- (void) registerObject: (id <OPPersisting>) object
{
	NSParameterAssert([object currentOID]>0); // hashing is based on oids here
    
	//NSLog(@"Will register object 0x%x for oid %llx", object, [object currentOID]);
	
    @synchronized((id)registeredObjects) {
        NSHashInsertIfAbsent(registeredObjects, object);
    }
	
	if ([[object class] cachesAllObjects]) {
		[self cacheObject: object];
	}
	
	[instanceStatistic addObject: [(NSObject*)object classForCoder]];
	
	if ([self objectRegisteredForOID: [object oid]] != object) {
		NSAssert([self objectRegisteredForOID: [object oid]] == object, @"registerObject: failed.");
	}
}

- (void) unregisterObject: (id <OPPersisting>) object
/*" Called by -[OPPersistentObject dealloc] to make sure we do not keep references to stale objects. "*/
{
	if ([object currentOID]) {
		@synchronized((id)registeredObjects) {
			NSHashRemove(registeredObjects, object);
		}
		[instanceStatistic removeObject: [(NSObject*)object classForCoder]];
	}
}

- (id) objectRegisteredForOID: (OID) oid
/*" Returns a subclass of OPPersistentObject. "*/
{    
	FakeObject searchStruct;
	
    searchStruct.isa = [OPPersistentObject class]; //classes[CIDFromOID(oid)]; // optimize
    searchStruct.oid = oid;
    
    OPPersistentObject *result = nil;
    
    @synchronized((id)registeredObjects) {
        result = NSHashGet(registeredObjects, &searchStruct);
		[[result retain] autorelease];
    }
    
    //NSLog(@"Object registered for oid %llu: %@", oid, result);
    return result;
}

- (void) didChangeObject: (id <OPPersisting>) object
/*" Marks object for saving. This method retains object until changes are saved. Does nothing, if this object has no oid set. "*/
{
	@synchronized((id)changedObjects) {
		//[self insertObject: object];
		if ([object currentOID]) { 
			[changedObjects addObject: object];  
		}
	}
}

	/*
- (void) willAccessObject: (OPPersistentObject*) fault forKey: (NSString*) key 
{

}
	 */

- (void) willFireFault: (OPPersistentObject*) fault forKey: (NSString*) key
/*" The key parameter denotes the reason fault is fired (a key-value-coding key). Currently only used for statistics. "*/
{
	[statistics.faultFireCountsByKey addObject: key];
}


- (void) willRevertObject: (id <OPPersisting>) object
{
	@synchronized(changedObjects) {
		[changedObjects removeObject: object]; 
	}
}

- (void) didRevertObject: (id <OPPersisting>) object
{
}

- (id) unarchiveObject: (id <OPPersisting>) result atCursor: (OPIntKeyBTreeCursor*) readCursor
{
	NSParameterAssert([readCursor isValid]);
	NSMutableData* data = [[NSMutableData alloc] init];
	OID oid = [readCursor currentEntryIntKey]; 
	[readCursor appendCurrentEntryValueToData: data];
	[result setOID: oid];
	[decoder unarchiveObject: result fromData: data];
	[data release];
	return result;	
}

- (id) rootObjectForKey: (NSString*) key
/*" Root objects are retained by the context upon first useage. "*/
{
	NSAssert(rootObjectOIDs != nil, @"rootObjectOIDs dictionary not set up.");
	id result = [rootObjects objectForKey: key];
	if (! result) {
		NSNumber* oidNumber = [rootObjectOIDs objectForKey: key];
		if (oidNumber) {
			result = [self objectForOID: [oidNumber unsignedLongLongValue]];
			if (result) {
				// Cache the result:
				[rootObjects setObject: result forKey: key];
			}
		}
	}
	return result;
}

- (void) setRootObject: (id <OPPersisting>) pObject forKey: (NSString*) key
{
	NSAssert(rootObjectOIDs != nil, @"Root object oid table not set up");
	NSNumber* oidNumber = [NSNumber numberWithUnsignedLongLong: [pObject oid]];
	[self insertObject: pObject];
	// Check, if we are indeed changing the value:
	if (! [[rootObjectOIDs objectForKey: key] isEqual: oidNumber]) {
//		if (! rootObjectOIDs) {
//			rootObjectOIDs = [[NSMutableDictionary alloc] init];
//			rootObjects = [[NSMutableDictionary alloc] init];
//		}
		[rootObjectOIDs setObject: oidNumber forKey: key];
		[rootObjects setObject: pObject forKey: key];
		[database setPlist: rootObjectOIDs forOid: ROOTOBJECTSOID error: NULL];
	}
}

NSString* OPStringFromOID(OID oid)
{
	OPPersistentObjectContext* context = [OPPersistentObjectContext defaultContext];
	unsigned cid = CIDFromOID(oid);
	Class theClass = [context classForCID: cid];
	NSString *result = [NSString stringWithFormat: @"%@, lid %llx", theClass, LIDFromOID(oid)];
	return result;
}

- (BOOL) unarchiveObject: (NSObject<OPPersisting>*) object forOID: (OID) oid
{
	int error = SQLITE_OK;
	OPIntKeyBTreeCursor* readCursor = [[database objectTree] newCursorWithError: &error];
	int pos = [readCursor moveToIntKey: oid error: &error];
	if (pos == 0 && error == SQLITE_OK) {
		[self unarchiveObject: object atCursor: readCursor];
	} else {
		NSLog(@"Warning - no object data found for %@", OPStringFromOID(oid));
		object = nil;
	}
	[readCursor release];
	[object awakeAfterUsingCoder: decoder];
	return object != nil;
}

// 2008-01-17 00:59:12.223 Gina[1533:10b] Warning - no object data found for GIThread, lid 30


- (id) objectForOID: (OID) oid
/*" Returns (a fault for) the persistent object (subclass of OPPersistentObject) with the oid given. It does so, regardless wether such an object is contained in the database or not. The result is autoreleased. For NILOID, returns nil. "*/
{
	if (!oid) return nil;
	//int oidSize = sizeof(oid);
	if (NSDebugEnabled) NSLog(@"Requesting object for oid %016llx", oid);
	// First, look up oid in registered objects cache:
    OPPersistentObject* result = [self objectRegisteredForOID: oid];
    if (!result) { 
        // not found - create a fault object:
		statistics->instancesLoaded++;
        //result = [[[poClass alloc] initFaultWithContext: self oid: oid] autorelease]; // also registers result with self
		Class theClass = [self classForCID: CIDFromOID(oid)];
		result = [theClass alloc];
		
		BOOL ok = [self unarchiveObject: result forOID: oid];
		if (! ok) {
			[result release];
			return nil;
		} 
		[result autorelease];
		[result setOID: oid]; // registers result - do not do that until we know there is data for oid

		//NSLog(@"Caching persistent object (oid 0x%016llx)", oid);
		//result = [[self unarchiveObject: result] autorelease];
		
		//NSLog(@"Registered object %@, lookup returns %@", result, [self objectRegisteredForOid: oid ofClass: poClass]);
		if (result != [self objectRegisteredForOID: oid]) {
			NSAssert(result == [self objectRegisteredForOID: oid], @"Problem with hash lookup. -hash method noch implemented by returning LID?");
		}
    } else {
		// We already know this object.
		// Put it into  the fault cache:
		if (! [[result class] cachesAllObjects]) {
			@synchronized (faultCache) {
				[faultCache addObject: result]; // cache result
				if ([faultCache count] > faultCacheSize) {
					[faultCache removeObjectAtIndex: 0]; // might release some object
				}
			}
		}
	}
    return result;
}

- (id) objectWithURLString: (NSString*) urlString
/*" Returns (possibly a fault object to) an OPPersistentObject. "*/
{
	if (!urlString) return nil;
	
	NSArray* pathComponents = [[urlString stringByReplacingPercentEscapesUsingEncoding: NSISOLatin1StringEncoding] pathComponents];
	NSParameterAssert([pathComponents count]>=3);
	//NSParameterAssert([[pathComponents objectAtIndex: 0] isEqualToString: @"x-opo"]);
	//NSParameterAssert([[db name] isEqualToString: [pathComponents objectAtIndex: 2]]);
	NSString* className = [pathComponents objectAtIndex: 1];
	Class pClass = NSClassFromString(className);
	NSString*  lidString = [pathComponents objectAtIndex: 2];

    if (pClass == NULL) return nil;
    
	CID cid = [self cidForClass:pClass];
	LID lid = OPLongStringValueBase16(lidString);
	OID oid = MakeOID(cid, lid);
	NSLog(@"Requesting object for oid %llx", oid);
	id result = [self objectForOID: oid];
	
	return result;
}

/*" Cursor is created on demand, if nil. "*/
- (void) archiveObject: (NSObject <OPPersisting>*) object 
		   usingCursor: (OPIntKeyBTreeCursor*) cursor
{
	@synchronized(encoder) {
		NSData* data = [encoder dataFromObject: object];
		OID oid = [object oid];
		if (! cursor) {
			cursor = [[[database objectTree] newCursorWithError: NULL] autorelease];
		}
		[cursor insertValueBytes: [data bytes] 
						ofLength: [data length] 
					   forIntKey: oid
						isAppend: NO];
	}
}

- (BOOL) oidIsValid: (OID) oid
{
	return oid == NILOID || [self classForCID: CIDFromOID(oid)] != nil;
}

static BOOL	oidEqual(NSHashTable* table, const void* object1, const void* object2)
{	
	//const FakeObject* o1 = object1;
	//const FakeObject* o2 = object2;
	BOOL fastResult = (((FakeObject*)object1)->oid == ((FakeObject*)object2)->oid);
	
	//NSLog(@"Comparing %@ and %@.", object1, object2);
	// Optimize by removing 2-4 method calls:
	//BOOL result = [(OPPersistentObject*)object1 currentOid] == [(OPPersistentObject*)object2 currentOid] && [(OPPersistentObject*)object1 class]==[(OPPersistentObject*)object2 class];
	//NSCAssert(fastResult == result, @"fastResult oidEqual failed.");
	return fastResult;
}


static unsigned	oidHash(NSHashTable* table, const void * object)
/* Hash function used for the registered objects table, based on the object oid. 
 * Newly created objects do have a changing oid and so cannot be put into 
 * the registeredObjects hashTable.
 */
{
	//unsigned fastResult = (unsigned)(((FakeObject*)object)->oid) ^ (unsigned)(((FakeObject*)object)->isa);
	unsigned fastResult = (unsigned)((FakeObject*)object)->oid;
	//NSAssert(fastResult == result, @"fastResult hashing failed.");
	return fastResult;
}

- (void) reset
/*" Resets the internal state of the receiver, excluding the database connection. The context can be used afterwards. "*/
{
	int error = SQLITE_OK;
	[self revertChanges]; // just to be sure

	NSHashTableCallBacks htCallBacks = NSNonRetainedObjectHashCallBacks;
	//htCallBacks.hash = &oidHash; // does not work with classes that do not inherit from OPPersistentObject (like OPStringDictionary)
	//htCallBacks.isEqual = &oidEqual; // does not work with classes that do not inherit from OPPersistentObject (like OPStringDictionary)
	
	[registeredObjects release];
	registeredObjects = NSCreateHashTable(htCallBacks, 1000);
	
	[allObjectsByClass release]; allObjectsByClass = nil;
	allObjectsByClass = [[NSMutableDictionary alloc] init];

	//[cidsByClass release];
	if (!cidsByClass) {
		cidsByClass = NSCreateMapTable(NSNonRetainedObjectMapKeyCallBacks, NSIntegerMapValueCallBacks, 30);
	}
	
	[encoder release];
	encoder = [[OPKeyedArchiver alloc] initWithContext: self];
	
	[rootObjects release]; rootObjects = [[NSMutableDictionary alloc] init];
	[rootObjectOIDs release];
	rootObjectOIDs = [[database plistForOid: ROOTOBJECTSOID error: &error] retain];
	if (! rootObjectOIDs) rootObjectOIDs = [[NSMutableDictionary alloc] init];
	
	[decoder release];
	decoder = [[OPKeyedUnarchiver alloc] initWithContext: self];
	
	[statistics reset];
	
	 @synchronized(changedObjects) {
		 [changedObjects release]; changedObjects = [[NSMutableSet alloc] init]; 
		 [deletedObjects release]; deletedObjects = [[NSMutableSet alloc] init];
		 //[cachedObjectsByClass release]; cachedObjectsByClass = [[NSMutableDictionary alloc] init];
	 }
	
	faultCacheSize = 10000;
	[faultCache release]; faultCache = [[NSMutableArray alloc] initWithCapacity: faultCacheSize+1];
	
	[instanceStatistic release]; instanceStatistic = [[NSCountedSet alloc] init];

	
//	@synchronized(database) {
//		if ([database isInTransaction]) {
//			[database commitTransaction];
//			[database beginTransaction];
//		}
//	}
}

- (id) init 
{
    if (self = [super init]) {
		statistics = [[OPPersistenceStatistics alloc] init];
        [self reset];      

    }
    return self;
}

- (void) populateMaxLidArray
{
	unsigned cid = 1;
	NSLog(@"Finding maximum lids...");
	OPIntKeyBTreeCursor* cursor = [[database objectTree] newCursorWithError: NULL];
	while (cid<256) { // optimize by using last cid found to skip cids ot used
		int error = 0;
		//NSLog(@"Finding max lid for cid %u", cid);
		// find entry with the largest lid for cid:
		OID queryOid = (MakeOID(cid+1, 0))-1;
		int pos = [cursor moveToIntKey: queryOid error: &error];
		//NSAssert1(pos<0, @"Strange cursor position while looking up max lid for cid %u.", cid);
		OID oidFound = 0;
		maxLid[cid] = 0; // init

		oidFound = [cursor currentEntryIntKey];

		if (pos>0) {
			[cursor moveToPrevious]; 
			oidFound = [cursor currentEntryIntKey];
		}
		//pos = [cursor moveToNext];
		//OID oidFound2 = [cursor currentEntryIntKey];

		if (CIDFromOID(oidFound) == cid) {
			// Found maximum oid for cid
			maxLid[cid] = LIDFromOID(oidFound);
			NSLog(@"Found max lid for cid %u (%@) to be %llu", cid, [self classForCID: cid], maxLid[cid]);
			// Cache all instances, if the class wants that:
			if ([classes[cid] cachesAllObjects]) {
				BOOL moveOk = YES;
				do {
					NSObject<OPPersisting>* instance = [classes[cid] alloc];
					instance = [self unarchiveObject: instance atCursor: cursor]; // also sets oid and registers instance and caches object
					
					OID oid = [instance oid];
					NSAssert(CIDFromOID(oid) == cid, @"Problem with oid generation.");
					if ([self objectRegisteredForOID: oid] != instance) {
						NSAssert([self objectRegisteredForOID: oid] == instance, @"Object not properly registered.");
					}
					moveOk = [cursor moveToPrevious];
					oidFound = [cursor currentEntryIntKey];
				} while (moveOk && CIDFromOID(oidFound) == cid);
			}
			
		}
		cid++;
	}
}

- (void) setDatabase: (OPDBLite*) newDB
{
	//if (database =! newDB) {
	[database autorelease];
	database = [newDB retain];
	int error = SQLITE_OK;
	// Load the class table:
	NSDictionary* plist = [database plistForOid: CLASSTABLEOID error: &error];
	for (NSString* cidString in plist) {
		unsigned cid = [cidString integerValue];
		NSString* className = [plist objectForKey: cidString];
		Class poClass = NSClassFromString(className);
		if (poClass) {
			if (NSDebugEnabled) NSLog(@"Registering persistent class %@ (cid %u)", poClass, cid);
			classes[cid] = poClass;
			NSMapInsert(cidsByClass, poClass, (void*)cid);
		}
	}
	int rc = [database beginTransaction];
	if (rc) {
		rc = [database rollbackTransaction];
		rc = [database beginTransaction];
	}
	NSAssert1(rc==SQLITE_OK, @"Unable to start db transaction: %d", rc);

	// Pre-populate these classes, if necessary:
	[self cidForClass: [NSString class]];
	[self cidForClass: [NSNumber class]];
	[self cidForClass: [NSData class]];
	
	NSAssert([database isInTransaction], @"Unable to start db transaction");

	rootObjectOIDs = [[database plistForOid: ROOTOBJECTSOID error: &error] retain];
	if (! rootObjectOIDs) rootObjectOIDs = [[NSMutableDictionary alloc] init];
	
	
	[self populateMaxLidArray];

}

- (void) setDatabaseFromPath: (NSString*) aPath
{
	int error = 0;
	databasePath = [aPath retain];
    OPDBLite* dbc = [OPDBLite databaseFromFile: databasePath flags: 0 error: &error];
    [self setDatabase: dbc];
}
 


- (NSSet*) changedObjects
{
	return changedObjects;
}

- (OPFaultingArray*) deletedObjects
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
	if ([changedObjects count] + [deletedObjects count] == 0) {
		return;
	}
		
	NSLog(@"Saving %u changed objects...\n%@", [changedObjects count],  /*NSDebugEnabled ? changedObjects :*/ @"");
	NSLog(@"Deleting %u objects...\n%@", [deletedObjects count],  /*NSDebugEnabled ? [deletedObjects allObjects] :*/ @"");

	@synchronized(self) {
		NSParameterAssert([database isInTransaction]); // Make sure, there is a transaction running
		int error = SQLITE_OK;

		OPIntKeyBTreeCursor* saveCursor = [[[self database] objectTree] newCursorWithError: &error];
		
		@synchronized(changedObjects) {
			OPPersistentObject* object;
			while (object = [changedObjects anyObject]) {
				NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
				if (NSDebugEnabled) NSLog(@"Archiving %@", object);
				[object willSave];
				[self archiveObject: object usingCursor: saveCursor];
				[changedObjects removeObject: object];
				[pool release];
			}
		}
		
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		@synchronized(deletedObjects) {
			OPPersistentObject* object;
			while (object = [deletedObjects anyObject]) {
				if (NSDebugEnabled) NSLog(@"Deleting %@", object);
				[saveCursor deleteEntriesWithIntKey: [object oid]];
				[deletedObjects removeObject: object];
			}
		}
		[pool release];

									 
		[saveCursor release];
									 
		error = [database commitTransaction];
		error = [database beginTransaction];
		
	}
	
	NSLog(@"Allocated instances after -saveChanges: %@\nContext: %@", instanceStatistic, self);
}

- (void) deleteObject: (OPPersistentObject*) object
/*" Marks object for deletion on the next -saveChanges call. "*/
{
	if ([object currentOID]) {
		// Object has been stored persistently, so we need to delete it:
		@synchronized(changedObjects) { // changedObjects also locks deletedObjects
			if (![deletedObjects containsObject: object]) {
				[deletedObjects addObject: object];
				[changedObjects removeObject: object]; // make sure, it is not inserted again
				[object willDelete];
				//[[cachedObjectsByClass objectForKey: [object class]] removeObject: object];
			}
			
			// Remove object from the all-objects cache:
			NSMutableSet* cache = [allObjectsByClass objectForKey: [[object classForCoder] description]]; // might be nil - ok!
			[cache removeObject: object];
		}
	}
}

- (void) revertChanges
{
	@synchronized(self) {
		
		OPIntKeyBTreeCursor* readCursor = [[database objectTree] newCursorWithError: NULL];
		NSMutableData* data = [[NSMutableData alloc] init];

		//NSLog(@"Reverting %u objects: ", [changedObjects count]);
		
		@synchronized(changedObjects) {
			OPPersistentObject* changedObject;
			while (changedObject = [changedObjects anyObject]) {
				//NSLog(@"Reverting %@", changedObject);
				[changedObject willRevert];
				// revert to database state:
				[data setLength: 0];
				[readCursor appendEntryValueForIntKey: [changedObject oid] toData: data];
				[decoder unarchiveObject: changedObject fromData: data];
				
				[changedObjects removeObject: changedObject];
			}
		}
		
		[data release];
		
		@synchronized(database) { // to be gone
			if ([database isInTransaction]) {
				[database rollbackTransaction]; // in case one is in progress
				[database beginTransaction];
			}
		}
		
	}
}

- (void) close
/*" No persistent objects or the receiver can be used after calling this method. "*/
{
	if (database) {
		@synchronized(database) {
			[self reset]; 
			[database release]; database = nil;
			if (self == [OPPersistentObjectContext defaultContext]) {
				[OPPersistentObjectContext setDefaultContext: nil];
			}
		}
	}
}

- (OPKeyedArchiver*) encoder
{
	return encoder;
}

- (OPKeyedUnarchiver*) decoder
{
	return decoder;
}

- (NSString*) databasePath
{
	return databasePath;
}

- (void) dealloc
{
    [self close]; // ok, if already closed

    [statistics release];
	[deletedObjects release];
	[changedObjects release];
	[encoder release]; encoder = nil;
	[decoder release]; decoder = nil;
	[cidsByClass release];
	[databasePath release];
	[rootObjects release];
	[rootObjectOIDs release];
	[instanceStatistic release];
	[super dealloc];
}

- (NSString*) description
{
	return [NSString stringWithFormat: @"%@ registered instances: %u,  faultCacheSize: %u, %@", [super description], NSCountHashTable(registeredObjects), faultCache.count, statistics];
}

- (OPDBLite*) database
{
	return database;
}


- (CID) cidForClass: (Class) poClass
{
	unsigned result = (unsigned)NSMapGet(cidsByClass, poClass);
	if (result) {
		return (CID) result;
	}
	int error = SQLITE_OK;
	NSMutableDictionary* plist = [NSMutableDictionary dictionary]; // plist out of the table for simple persistence
	long newCid = 1;
	while (newCid<256 && classes[newCid] != nil) {
		[plist setObject: NSStringFromClass(classes[newCid]) forKey: [[NSNumber numberWithUnsignedInt: newCid] description]];
		newCid++;
	}
	[plist setObject: NSStringFromClass(poClass) forKey: [[NSNumber numberWithUnsignedInt: newCid] description]];
	classes[newCid] = poClass;
	NSMapInsert(cidsByClass, poClass, (void*)newCid);
	
	NSLog(@"Registering persistent class %@ (cid %u)", poClass, newCid);

	//if (NSDebugEnabled) NSLog(@"Storing plist with cid mappings: %@", plist);

	// Make a plist out of the table and store that:
	[database setPlist: plist forOid: CLASSTABLEOID error: &error];
	
	
	NSAssert([self cidForClass: poClass] == newCid, @"Internal error in class table bookkeeping.");
	return newCid;
}

- (Class) classForCID: (CID) cid
{
	if (cid>=256) {
	NSParameterAssert(cid<256);
	}
	return classes[cid];
}

- (OID) nextOIDForClass: (Class) poClass
{
	// determine cid for poClass:
	CID cid = [self cidForClass: poClass];
	// See, if we know the highest lid used:
	OID oid = MakeOID(cid, ++maxLid[cid]);
	return oid;
}

- (void) insertObject: (id <OPPersisting>) newObject
/*" inserts newObject into the receiver context and sets an oid. Does nothing, if newObject already has an oid. Ignores nil newObjects. "*/
{
	if (newObject) {	NSParameterAssert([newObject context] == NULL || [newObject context] == self);
		if (![newObject currentOID]) {
			OID newOID = [self nextOIDForClass: [newObject class]];
			[newObject setOID: newOID]; // also registers newObject with self
			[self didChangeObject: newObject];
		}
	}
}


@end


@implementation NSCoder (OPPersistence)

- (OID) decodeOIDForKey: (NSString*) key
/*" Regular decoders do encode the object, insert it as new object into the default context and return its oid. "*/
{
	NSObject<OPPersisting>* object = [self decodeObjectForKey: key];
	[self.context insertObject: object];
	return [object oid];
}

- (void) encodeOID: (OID) oid forKey: (NSString*) key
/*" Regular encoders do encode the object directly instead of the oid. "*/
{
	[self encodeObject: [self.context objectForOID: oid] forKey: key];
}

- (OPPersistentObjectContext*) context
{
	return [OPPersistentObjectContext defaultContext];
}

@end

@implementation OPPersistenceStatistics

- (void) reset
{
	// Reset statistics:
	instancesLoaded = 0;
	numberOfObjectsSaved = 0;
	numberOfObjectsDeleted = 0;
	[faultFireCountsByKey autorelease]; faultFireCountsByKey = [[NSCountedSet alloc] init];
}

- (NSString*) description
{
	return [NSString stringWithFormat: @"Instance Statistics (total numbers):\n#created: %u\n#saved : %u\n#deleted : %u\nFiring keys: %@\n", instancesLoaded, numberOfObjectsSaved, numberOfObjectsDeleted, faultFireCountsByKey];
}

- (NSCountedSet*) faultFireCountsByKey
{
	return faultFireCountsByKey;
}

- (id) init
{
	if (self = [super init]) {
		[self reset];
	}
	return self;
}


- (void) dealloc 
{
	[faultFireCountsByKey release];
	[super dealloc];
}

@end