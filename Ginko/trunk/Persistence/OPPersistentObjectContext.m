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
#import "OPClassDescription.h"
#import "OPFaultingArray.h"
#import "NSString+Extensions.h"
#import <OPObjectPair.h>
#import "OPObjectRelationship.h"

@implementation OPPersistentObjectContext

static long long OPLongLongStringValue(NSString* self)
{
	char buffer[100];
	[self getCString: buffer maxLength: 99];
	return atoll(buffer);	
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
        [defaultContext release];
        defaultContext = [context retain];
    }
}



// SearchStruct is a fake object made for searching in the hashtable:
typedef struct {
	Class isa;
	OID oid;
	NSMutableDictionary* attributes;
} FakeObject;

- (void) registerObject: (OPPersistentObject*) object
{
	NSParameterAssert([object currentOid]>0); // hashing is based on oids here
    NSHashInsertIfAbsent(registeredObjects, object);
}

- (void) unregisterObject: (OPPersistentObject*) object
/*" Called by -[OPPersistentObject dealloc] to make sure we do not keep references to stale objects. "*/
{
    @synchronized(self)
    {
        NSHashRemove(registeredObjects, object);
    }
}

- (id) objectRegisteredForOid: (OID) oid ofClass: (Class) poClass
/*" Returns a subclass of OPPersistentObject. "*/
{
	FakeObject searchStruct;
	
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
	@synchronized(self) {
		[changedObjects addObject: object];  
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
	[faultFireCountsByKey addObject: key];
}

- (void) didChangeObject: (OPPersistentObject*) object
{
    //[lock unlock];
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
	OID newOid;
	@synchronized(self) {
		if (![db transactionInProgress]) [db beginTransaction]; // transaction is committed on -saveChanges
		newOid = [db insertNewRowForClass: [object class]];
		NSAssert1(newOid, @"Unable to insert row for new object %@", object);
		[changedObjects addObject: object]; // make sure the values make it into the database
	}
	return newOid;
}

- (id) objectForOid: (OID) oid ofClass: (Class) poClass
/*" Returns (a fault for) the persistent object with the oid given of class poClass (which must be a subclass of OPPersistentObject). It does so, regardless wether such an object is contained in the database or not. The result is autoreleased. For NILOID, returns nil. "*/
{
	if (!oid) return nil;
	
	// First, look up oid in registered objects cache:
    OPPersistentObject* result = [[self objectRegisteredForOid: oid ofClass: poClass] retain];
    if (!result) { 
        // not found - create a fault object:
		numberOfFaultsCreated++;
        result = [[poClass alloc] initFaultWithContext: self oid: oid]; // also registers result with self
		//NSLog(@"Registered object %@, lookup returns %@", result, [self objectRegisteredForOid: oid ofClass: poClass]);
        //NSAssert(result == [self objectRegisteredForOid: oid ofClass: poClass], @"Problem with hash lookup");
    } else {
		// We already know this object.
		// Put it in the fault cache:
		//unsigned retainCount = [result retainCount];
		[faultCache addObject: result]; // cache result
		if ([faultCache count] > faultCacheSize) {
			[faultCache removeObjectAtIndex: 0]; // release some object
		}	
	}
    return [result autorelease];
}

- (id) objectWithURLString: (NSString*) urlString
/*" Returns (possibly a fault object to) an OPPersistentObject. "*/
{
	NSArray* pathComponents = [[urlString stringByReplacingPercentEscapesUsingEncoding: NSISOLatin1StringEncoding] pathComponents];
	NSParameterAssert([pathComponents count]>=4);
	//NSParameterAssert([[pathComponents objectAtIndex: 0] isEqualToString: @"x-opo"]);
	//NSParameterAssert([[db name] isEqualToString: [pathComponents objectAtIndex: 2]]);
	NSString* className = [pathComponents objectAtIndex: 2];
	Class pClass = NSClassFromString(className);
	if (!pClass) {
		// Fallback for transition from CoreData. Can be removed later:
		pClass = NSClassFromString([@"GI" stringByAppendingString: className]);
	}
	NSString* oidString = [pathComponents objectAtIndex: 3];

	OID oid = OPLongLongStringValue(oidString);
	if (oid==0LL && [oidString hasPrefix: @"p"]) {
		// Fallback for transition from CoreData. Can be removed later:
		oid = OPLongLongStringValue([oidString substringFromIndex: 1]);
	}
	return [self objectForOid:  oid ofClass: pClass];
}

- (NSDictionary*) persistentValuesForObject: (OPPersistentObject*) object
{
	NSParameterAssert(object!=nil);
	OID oid = [object currentOid];
	id result = nil;
	@synchronized(self) {
		if (oid) {
			result = [db attributesForRowId: oid ofClass: [object class]];
			if (!result) {
				NSLog(@"Faulting problem: %@ with oid %llu not in the database!?", [object class], oid);
			}
		} else {
			result = [NSMutableDictionary dictionary];
		}
		numberOfFaultsFired++;
	}
	return result;
}

static BOOL	oidEqual(NSHashTable* table, const void* object1, const void* object2)
{
	//NSLog(@"Comparing %@ and %@.", object1, object2);
	// Optimize by removing 2-4 method calls:
	return [(OPPersistentObject*)object1 currentOid] == [(OPPersistentObject*)object2 currentOid] && [(OPPersistentObject*)object1 class]==[(OPPersistentObject*)object2 class];
	//const FakeObject* o1 = object1;
	//const FakeObject* o2 = object2;
	
	//return (o1->oid == o2->oid) && (o1->isa == o2->isa);
}


static unsigned	oidHash(NSHashTable* table, const void * object)
/* Hash function used for the registered objects table, based on the object oid. 
 * Newly created objects do have a changing oid and so cannot be put into 
 * the registeredObjects hashTable.
 */
{
	unsigned result = (unsigned)[(OPPersistentObject*)object currentOid];
	//unsigned result = (unsigned)(((FakeObject*)object)->oid) ^ (unsigned)(((FakeObject*)object)->isa);
	return result;
}

- (void) reset
/*" Resets the internal state of the receiver, excluding the database connection. The context can be used afterwards. "*/
{
	[self revertChanges]; // just to be sure

	NSHashTableCallBacks htCallBacks = NSNonRetainedObjectHashCallBacks;
	htCallBacks.hash = &oidHash;
	htCallBacks.isEqual = &oidEqual;
    if (registeredObjects) NSFreeHashTable(registeredObjects);
    registeredObjects = NSCreateHashTable(htCallBacks, 1000);
    
	// Reset statistics:
	 numberOfFaultsFired = 0; 
	 numberOfRelationshipsFired = 0;
	 numberOfFaultsCreated = 0;
	 numberOfObjectsSaved = 0;
	 numberOfObjectsDeleted = 0;
	 [faultFireCountsByKey release]; faultFireCountsByKey = [[NSCountedSet alloc] init];
	
    [changedObjects release]; changedObjects = [[NSMutableSet alloc] init]; 
    [deletedObjects release]; deletedObjects = [[NSMutableSet alloc] init];
	
	[relationshipChangesByJoinTable release];
	relationshipChangesByJoinTable = [[NSMutableDictionary alloc] init];
	faultCacheSize = 50;
	[faultCache release]; faultCache = [[NSMutableArray alloc] initWithCapacity: faultCacheSize+1];
	
	[db close];
	[db open];
	
}

- (id) init 
{
    if (self = [super init]) {
        [self reset];       
		//lock = [[NSLock alloc] init];
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

- (void) checkDBSchemaForClasses: (NSString*) classListSeparatedByComma;
{
	NSMutableSet* classesChecked = [NSMutableSet set];
	NSArray* classList = [classListSeparatedByComma componentsSeparatedByString: @","];
	NSEnumerator* e = [classList objectEnumerator];
	NSString* className;
	while (className = [[e nextObject] stringByRemovingSurroundingWhitespace]) {
		Class pClass = NSClassFromString(className);
		if (pClass) {
			[classesChecked addObject: pClass];
			OPClassDescription* cd = [pClass persistentClassDescription];
			[cd checkTableUsingConnection: db];
		}
	}
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
	//[lock lock];
	@synchronized(self) {
		
		//[OPPersistentObjectEnumerator printAllRunningEnumerators];
		NSLog(@"Open statements: %@", [OPSQLiteStatement runningStatements]);
		
		//[[OPSQLiteStatement runningStatements] makeObjectsPerformSelector: @selector(reset)];
		
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init]; // me might produce a lot of temp. objects
		
		if (![db transactionInProgress]) [db beginTransaction];
		//[db commitTransaction]; [db beginTransaction]; // just for testing
		
		if ([changedObjects count]) {
			NSLog(/*OPDebugLog(OPPERSISTENCE, OPINFO, */@"Saving %u object(s).", [changedObjects count]);
			
			// Process all updated objects and save their changed attribute sets:
			NSEnumerator* coe = [changedObjects objectEnumerator];
			OPPersistentObject* changedObject;
			while (changedObject = [coe nextObject]) {
				
				[changedObject willSave];
				
				OID newOid = [db updateRowOfClass: [changedObject class] 
											rowId: [changedObject currentOid] 
										   values: [changedObject attributeValues]];
				
				[changedObject setOid: newOid]; // also registers object
				
			}
			
			numberOfObjectsSaved += [changedObjects count];
			// Release all changed objects:
			[changedObjects release]; changedObjects = [[NSMutableSet alloc] init];
		}	
		
		[pool release]; pool = [[NSAutoreleasePool alloc] init];
		
		//[db commitTransaction]; [db beginTransaction]; // just for testing
		
		if ([deletedObjects count]) {
			
			NSLog(@"Deleting %u objects from the database", [deletedObjects count]);
			NSEnumerator* coe = [deletedObjects objectEnumerator];
			OPPersistentObject* deletedObject;
			while (deletedObject = [coe nextObject]) {
				
				//NSLog(@"Will honk %@", deletedObject);
				[db deleteRowOfClass: [deletedObject class] 
							   rowId: [deletedObject currentOid]];
				
				[changedObjects removeObject: deletedObject];
			}
			
			numberOfObjectsDeleted += [deletedObjects count];
			// Release all changed objects:
			[deletedObjects release]; deletedObjects = [[NSMutableSet alloc] init];
		}
		
		NSEnumerator* renum = [relationshipChangesByJoinTable objectEnumerator];
		OPObjectRelationship* relationshipChanges;
		while (relationshipChanges = [renum nextObject]) {
			
			if ([relationshipChanges changeCount]) {
				
				// Add a row in the join table for each relation added:
				OPSQLiteStatement* addStatement;
				addStatement = [db addStatementForJoinTableName: [relationshipChanges joinTableName] 
												firstColumnName: [relationshipChanges firstColumnName] 
											   secondColumnName: [relationshipChanges secondColumnName]];
				
				NSEnumerator* pairEnum = [relationshipChanges addedRelationsEnumerator];
				OPObjectPair* pair;
				
				while (pair = [pairEnum nextObject]) {
					
					OPPersistentObject* firstObject  = [pair firstObject];
					OPPersistentObject* secondObject = [pair secondObject];
					
					[addStatement reset];
					[addStatement bindPlaceholderAtIndex: 0 toRowId: [firstObject oid]];
					[addStatement bindPlaceholderAtIndex: 1 toRowId: [secondObject oid]];
					
					[addStatement execute];
				}
				[addStatement reset];
				
				// Remove a row in the join table to each relation removed:
				
				OPSQLiteStatement* removeStatement;
				removeStatement = [db removeStatementForJoinTableName: [relationshipChanges joinTableName] 
													  firstColumnName: [relationshipChanges firstColumnName] 
													 secondColumnName: [relationshipChanges secondColumnName]];
				
				pairEnum = [relationshipChanges removedRelationsEnumerator];
				
				while (pair = [pairEnum nextObject]) {
					
					OPPersistentObject* firstObject  = [pair firstObject];
					OPPersistentObject* secondObject = [pair secondObject];
					
					[removeStatement reset];
					[removeStatement bindPlaceholderAtIndex: 0 toRowId: [firstObject oid]];
					[removeStatement bindPlaceholderAtIndex: 1 toRowId: [secondObject oid]];
					
					[removeStatement execute];
				}		
				[removeStatement reset];
				
				[relationshipChanges reset]; // delete all changes as they are now recorded in the database
			}
		}
		
		[pool release]; pool = [[NSAutoreleasePool alloc] init];
		
		[db commitTransaction];
		
		[pool release];
		
	}
}

- (void) shouldDeleteObject: (OPPersistentObject*) object
/*" Marks object for deletion on the next -saveChanges call. "*/
{
	if ([object currentOid]) {
		// otherwise it has not been stored persistently, so we do not need to delete it
		if (![deletedObjects containsObject: object]) {
			
			[deletedObjects addObject: object];
			[changedObjects removeObject: object]; // make sure, it is not inserted again
			[object willDelete];
		}
	}
}



- (OPFaultingArray*) containerForObject: (id) object
						relationShipKey: (NSString*) key
/*" Returns the container specified in the attribute description. Currently, only OPFaultingArray is supported or nil if key does not
	denote a to-many relationship. Called from OPPersistentObject willAccessValueForKey... "*/
{
	OPClassDescription* cd          = [[object class] persistentClassDescription];
	OPAttributeDescription* ad      = [cd attributeWithName: key];
	NSString* sql                   = [ad queryString];
	NSString* sortKey               = nil; 
	Class     sortKeyClass          = nil;
	id        result                = nil;
	
	OPPersistentObjectEnumerator* e = nil;
	
	if ([ad isToManyRelationship] && sql != nil) {
		// We might want to cache these:
		if (sortKey = [ad sortAttributeName]) {
			sortKeyClass = [[[[ad attributeClass] persistentClassDescription] attributeWithName: sortKey] attributeClass];
		}
		
		numberOfRelationshipsFired++;
		
		e = [[OPPersistentObjectEnumerator alloc] initWithContext: self 
													   resultClass: [ad attributeClass] 
													   queryString: sql];
		[e bind: object, nil];
		result = [e allObjectsSortedByKey: sortKey ofClass: sortKeyClass];				
		[e release];
		
		OPObjectRelationship* rchanges = [self manyToManyRelationshipForAttribute: ad];
		if (rchanges) {
			// This is a many-to-many relation. Changes since the last -saveChanges are recorded in the OPObjectRelationship object and must be re-done:
			[rchanges updateRelationshipNamed: key from: object values: result];
		}
		
	}
	return result;
}

- (OPObjectRelationship*) manyToManyRelationshipForAttribute: (OPAttributeDescription*) ad 
{
	OPObjectRelationship* result = nil;
	NSString* joinTableName = [ad joinTableName];
	if (joinTableName) {
		result = [relationshipChangesByJoinTable objectForKey: joinTableName];
		if (!result) {
			OPAttributeDescription* iad = [ad inverseRelationshipAttribute]; // may return nil
			// Create it on demand:
			result = [[[OPObjectRelationship alloc] initWithAttributeDescriptions: ad : iad] autorelease];			
			[relationshipChangesByJoinTable setObject: result forKey: joinTableName];
		}
	}
	return result;
}

- (void) revertChanges
{
	//[lock lock];
	@synchronized(self) {
		
		OPPersistentObject* changedObject;
		while (changedObject = [changedObjects anyObject]) {
			[changedObject revert]; // removes itself from changedObjects
		}
		
		[db rollBackTransaction]; // in case one is in progress
		
		//[lock unlock];
	}
}

- (void) dealloc
{
    [self reset];

    [faultFireCountsByKey release];
	[deletedObjects release];
	[changedObjects release];
		
	[super dealloc];
}

- (NSString*) description
{
	return [NSString stringWithFormat: @"%@ #faults registered/created: %u/%u, #r'ships fired: %u, #saved: %u, #deleted: %u, \nfireKeys: %@", [super description], NSCountHashTable(registeredObjects), numberOfFaultsCreated, numberOfRelationshipsFired, numberOfObjectsSaved, numberOfObjectsDeleted, faultFireCountsByKey];
}

- (NSArray*) objectsForClass: (Class) poClass
				 queryFormat: (NSString*) sql, ...
{
	NSArray* result;
	@synchronized(self) {
		OPPersistentObjectEnumerator* e;
		e = [[OPPersistentObjectEnumerator alloc] initWithContext: self 
													  resultClass: poClass
													  queryString: sql];
		
		va_list ap; /* points to each unamed arg in turn */
		va_start(ap, sql); /* make ap point to 1st unnamed arg */
		unsigned index = 1; // change that! make it 0 based!
		id binding;
		while (binding = va_arg(ap, id)) {
			[binding bindValueToStatement: [e statement] index: index++];
		}
		va_end(ap); /* clean up when done */
		
		result = [e allObjects];
		[e release];
	}
	return result;
}

- (NSArray*) objectsForClass: (Class) poClass
				 whereFormat: (NSString*) clause, ...
	/*" Replaces all the question marks in the whereFormat string with the object 
	values passed. Valid object classes return YES to +[canPersist]. "*/
{
	NSArray* result;
	@synchronized(self) {
		OPPersistentObjectEnumerator* e;
		e = [[OPPersistentObjectEnumerator alloc] initWithContext: self 
													  resultClass: poClass
													  whereClause: clause];
		
		va_list ap; /* points to each unamed arg in turn */
		va_start(ap, clause); /* make ap point to 1st unnamed arg */
		unsigned index = 1; // change that! make it 0 based!
		id binding;
		while (binding = va_arg(ap, id)) {
			[binding bindValueToStatement: [e statement] index: index++];
		}
		va_end(ap); /* clean up when done */
		
		result = [e allObjects];
		[e release];
	}
	return result;
}

/*
- (NSArray*) objectsForClass: (Class) poClass
					   where: (NSString*) clause
{
	return [[[OPPersistentObjectEnumerator alloc] initWithContext: self 
													  resultClass: poClass
													  whereClause: clause] allObjects];
}
*/

@end

@implementation OPPersistentObjectEnumerator 

static NSHashTable* allInstances;

+ (void) initialize
{
	if (!allInstances) {
		allInstances = NSCreateHashTable(NSNonRetainedObjectHashCallBacks, 10);
	}
}

- (id) initWithContext: (OPPersistentObjectContext*) aContext
		   resultClass: (Class) poClass 
		   queryString: (NSString*) sql
{
	if (self = [super init]) {
		
		context     = [aContext retain];
		resultClass = poClass;
		
		@synchronized(context) {
			//[context lock];
			sqlite3_prepare([[context databaseConnection] database], [sql UTF8String], -1, &statement, NULL);	
			//[context unlock];
		}
		if (!statement) {
			NSLog(@"Error preparing statement: %@", [[context databaseConnection] lastError]);
			[self autorelease];
			return nil;
		}
		
		NSHashInsert(allInstances, self);
		
		//NSLog(@"Created enumerator statement %@ for table %@", sql, [resultClass databaseTableName]);
	} 
	return self;
}

- (id) initWithContext: (OPPersistentObjectContext*) aContext
		   resultClass: (Class) poClass 
		   whereClause: (NSString*) clause
{	
	NSString* queryString = [NSString stringWithFormat: ([clause length]>0 ? @"select ROWID from %@ where %@;" : @"select ROWID from %@;"), [[poClass persistentClassDescription] tableName], clause];

	return [self initWithContext: aContext resultClass: poClass queryString: queryString];
}

// "select ZMESSAGE.ROWID from ZMESSAGE, ZJOIN where aaa=bbb;"


- (void) bind: (id) variable, ...;

{
	// locking?
	//NSParameterAssert([[variable class] canPersist]);
	[variable bindValueToStatement: statement index: 1];
#warning todo: Implement vararg to support more than one variable binding.
	NSHashInsert(allInstances, self);
}


- (void) reset
{
	@synchronized(context) {
		//[context lock];
		sqlite3_reset(statement);
		NSHashRemove(allInstances, self);
		//[context unlock];
	}
}

- (BOOL) skipObject
	/*" Returns YES, if an object was skipped, NO otherwise (nothing to enumerate). Similar to nextObject, but does not create the result object (if any). "*/
{
	int res;
	//[context lock];
	@synchronized(context) {
		res = sqlite3_step(statement);
		
		if (res!=SQLITE_ROW) {
			[self reset]; // finished
		}
	}
	return (res==SQLITE_ROW);
}

- (NSArray*) allObjects
{
	return (NSArray*)[self allObjectsSortedByKey: nil ofClass: nil];
}

- (OPFaultingArray*) allObjectsSortedByKey: (NSString*) sortKey 
								   ofClass: (Class) sortKeyClass;
/*" Returns an OPFaultingArray containing all the faults.
	If sortKey is a key-value-complient key for the resultClass, the result is sorted by the key givenand the second result column is expected to contain the sort objects in ascending order while the first column must always contain ROWIDs. "*/
{
	OPFaultingArray* result = [OPFaultingArray array];
	[result setSortKey: sortKey];
	[result setElementClass: resultClass];
	while ([self skipObject]) {
		ROWID rid = sqlite3_column_int64(statement, 0);
		id sortObject = sortKey ? [sortKeyClass newFromStatement: statement index: 1] : nil;
		[result addOid: rid sortObject: sortObject];
	}
	return result;
}

- (sqlite3_stmt*) statement
{
	return statement;
}

- (id) nextObject
	/*" Returns the next fetched object including all its attributes. "*/
{
	id result = nil;
	
	@synchronized(context) {
		if (sqlite3_step(statement)==SQLITE_ROW) {
			result = [resultClass newFromStatement: statement index: 0];
			//[context unlock];
		} else {
			//NSLog(@"%@: Stopping enumeration. return code=%d", self, res);
			//[context unlock];
			[self reset]; // finished
		}
	}
	//NSLog(@"%@: Enumerated object %@", self, result);
	return result;
}

+ (void) printAllRunningEnumerators
{
	NSHashEnumerator e = NSEnumerateHashTable(allInstances);
	id item;
	while (item = NSNextHashEnumeratorItem(&e)) {
		NSLog(@"Running Enumerator: %@", item);
	}
	NSEndHashTableEnumeration(&e);
}

- (void) dealloc
{
	sqlite3_finalize(statement);
	[context release]; context = nil;
	NSHashRemove(allInstances, self);
	[super dealloc];
}


@end


NSString* OPURLStringFromOidAndClass(OID oid, Class poClass, NSString* databaseName)
{
	NSString* uriString = [[[NSString alloc] initWithFormat: @"x-opo://%@/%@/%lld", 
		[databaseName stringByAddingPercentEscapesUsingEncoding: NSISOLatin1StringEncoding], 
		poClass, oid] autorelease];
	return uriString;
}


