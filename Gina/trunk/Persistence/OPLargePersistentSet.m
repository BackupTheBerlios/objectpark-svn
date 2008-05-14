//
//  OPPersistentSet.m
//  BTreeLite
//
//  Created by Dirk Theisen on 15.11.07.
//  Copyright 2007 Dirk Theisen. All rights reserved.
//

#import "OPLargePersistentSet.h"
#import "OPPersistentObjectContext.h"



@interface OPLargePersistentSetArrayEnumerator : NSEnumerator {
	OPLargePersistentSetArray* array;
	OPLargePersistentSet* pSet;
	NSUInteger arrayCount;
	NSUInteger changeCount;
	NSUInteger nextIndex;
}

- (id) initWithPersistentSet: (OPLargePersistentSet*) theSet;

@end

@implementation OPLargePersistentSet

- (OPPersistentObjectContext*) context
{
	return [OPPersistentObjectContext defaultContext];
}

- (BOOL) containsObjectWithOID: (OID) oid sortKeyValue: (id) sortKeyValue
{
// TODO: implement containsObjectWithOID:sortKeyValue:
	return NO;
}

- (NSData*) newKeyForObject: (id) anObject
/*" Keys consist of the sort key data (if any), followed by the oid. "*/
{
	NSMutableData* result = [[NSMutableData alloc] init];
	if (sortKeyPath) {
// TODO: implement [anObject appendBTreeBytesForKey: sortKeyPath to: result]
		//[anObject appendBTreeBytesForKey: sortKeyPath to: result];
		int time = [(NSDate*)[anObject valueForKey: sortKeyPath] timeIntervalSince1970];
		time = NSSwapHostIntToBig(time);
		[result appendBytes: &time length: sizeof(time)];
	}	
	OID objectOid = NSSwapHostLongLongToBig([anObject oid]);
	[result appendBytes: &objectOid length: sizeof(OID)];
	return result;
}

- (OPBTree*) btree
{
	if (!btree) {
		btree = [[OPKeyOnlyBTree alloc] initWithCompareFunctionName: NULL withRoot: 0 inDatabase: [[self context] database]];
	}
	return btree;
}

- (OPBTreeCursor*) setterCursor
{
	if (! setterCursor) {
		int error = SQLITE_OK;
		setterCursor = [[self btree] newCursorWithError: &error];
		NSAssert(setterCursor, @"Unable to read from the database.");
	}
	return setterCursor;
}

- (void) addObject: (id) anObject
{
	NSData* keyData = [self newKeyForObject: anObject];
	//@synchronized(setCursor) {
	const void* keyBytes = [keyData bytes];
	i64 keyLength = [keyData length];
	NSAssert(keyLength >= sizeof(OID), @"Faulty btree key.");
	int pos = [[self setterCursor] moveToKeyBytes: keyBytes length: keyLength error: NULL];
	if (pos != 0)  {
		changeCount++;
		
		// todo: also do the set notification here
		[self willChangeValueForKey: @"sortedArray"]; // test, if we should post the indexed notification here
		[self willChangeValueForKey: @"count"];
		[[self setterCursor] insertValueBytes: NULL ofLength: 0 
								  forKeyBytes: keyBytes ofLength: keyLength isAppend: NO];
		if (count!=NSNotFound) count++;
		[array noteEntryAddedWithKeyBytes: keyBytes length: keyLength]; // does nothing, if no sortedArray set.
		[self didChangeValueForKey: @"count"];
		[self didChangeValueForKey: @"sortedArray"]; // test, if we should post the indexed notification here
	} else {
		// nothing to do, anObject already present
		NSLog(@"Ignoring addition of existing object to persistent set.");
	}
	//}
	[keyData release];
} 

- (id) member: (id) anObject
{
	NSData* keyData = [self newKeyForObject: anObject];
	const void* keyBytes = [keyData bytes];
	i64 keyLength = [keyData length];
	int pos = [[self setterCursor] moveToKeyBytes: keyBytes length: keyLength error: NULL];
	id result = nil;
	if (pos == 0)  {
		result = anObject;
	}
	[keyData release];
	return result;
}


- (void) removeObject: (id) anObject
{
	if (btree) {
		NSData* keyData = [self newKeyForObject: anObject];
		//@synchronized(setCursor) {
		const void* keyBytes = [keyData bytes];
		NSUInteger keyLength = [keyData length];
		int pos = [[self setterCursor] moveToKeyBytes: keyBytes length: keyLength error: NULL];
		if (pos == 0)  {
			changeCount++;
			
			// TODO: also do the set notification here
			[self willChangeValueForKey: @"sortedArray"];
			[[self setterCursor] deleteCurrentEntry];
			if (count != NSNotFound) {
				count--;
			}
			
			[array noteEntryRemovedWithKeyBytes: keyBytes length: keyLength];
			
			[self didChangeValueForKey: @"sortedArray"];
		} else {
			NSLog(@"Warning: Unable to find set element %@ for deletion in %@", anObject, self);
		}
		[keyData release];
	}
}



- (id) anyObject
{
	if (count == 0) return nil;
	
	OPLargePersistentSetArray* sarray = (OPLargePersistentSetArray*) [self sortedArray];
	NSUInteger pos = [sarray cursorPosition];
	if (pos == NSNotFound) {
		pos = 0;
	}
	
	id result = [sarray objectAtIndex: pos];
	return result;
}

- (NSString*) sortKeyPath
{
	return sortKeyPath;
}

- (void) setSortKeyPath: (NSString*) newSortKeyPath
{
	if (! [sortKeyPath isEqualToString: newSortKeyPath]) {
		[self willChangeValueForKey: @"sortKeyPath"];
		NSParameterAssert(sortKeyPath == nil || [self count] == 0);
		[newSortKeyPath release];
		sortKeyPath = [newSortKeyPath retain];
		[self didChangeValueForKey: @"sortKeyPath"];
	}
}

- (NSString*) descriptionWithLocale: (id) locale indent: (unsigned) indent
{
	return [NSString stringWithFormat: @"<%@ 0x%x> with %u entries", [self class], self, self.count];
}


- (void) dealloc 
{
	[sortKeyPath release];
	[setterCursor release];
	[btree release];
	[array forgetSet];
	[array release];
	[super dealloc];
}

- (NSArray*) sortedArray
/*" Array is sorted by oid, if no sortKey has been set, by sortKey, otherwise. "*/
{
	if (!array) {
		array = [[OPLargePersistentSetArray alloc] initWithPersistentSet: self];
	}
	return array;
}

- (void) willChangeValueForKey: (NSString*) key
{	
	[super willChangeValueForKey: key];
}

- (id) init
{
	count = NSNotFound;
	return self;
}

- (id) initWithCoder: (NSCoder*) coder
{
	int rootPage = [coder decodeInt32ForKey: @"BTreeRootPage"];
	NSString* keyCompareFunctionName = [[coder decodeObjectForKey: @"BTreeKeyCompareFunctionName"] retain];
	
	btree = [[OPKeyOnlyBTree alloc] initWithCompareFunctionName: keyCompareFunctionName 
													   withRoot: rootPage 
													 inDatabase: [[coder context] database]];
	
	sortKeyPath = [[coder decodeObjectForKey: @"OPSortKeyPath"] retain];
	count = NSNotFound;
	return self;
}

- (void) encodeWithCoder: (NSCoder*) coder
{
	[coder encodeInt: [btree rootPage] forKey: @"BTreeRootPage"];
	[coder encodeObject: [btree keyCompareFunctionName] forKey: @"BTreeKeyCompareFunctionName"];	
	[coder encodeObject: sortKeyPath forKey: @"OPSortKeyPath"];
}

- (OID) oid
/*" Returns the object id for the receiver or NILOID if the object has no context.
 Currently, the defaultContext is always used. "*/
{
	if (!oid) {
		@synchronized(self) {
			// Create oid on demand, this means that this is now becoming persistent.
			// Persistent objects unarchived are explicitly given an oid:
			
			OPPersistentObjectContext* context = [self context];
			if (context) {
				[context insertObject: self];
			}
		}
	}
	return oid;
}

- (OID) currentOID
/*" Private method to be used within the framework only. "*/
{
	return oid;
}

- (void) setOID: (OID) theOid
/*" Registers the receiver with the context, if neccessary. "*/
{
	@synchronized(self) {
		if (oid != theOid) {
			NSAssert(oid==0, @"Object ids can be set only once per instance.");
			oid = theOid;
			[[self context] registerObject: self];
		}
	}
}

- (NSEnumerator*) objectEnumerator
{
	//return self.sortedArray.objectEnumerator;
	return [[[OPLargePersistentSetArrayEnumerator alloc] initWithPersistentSet: self] autorelease];
}

- (Class) classForCoder
{
	return [self class];
}

- (NSUInteger) count
{
	if (count == NSNotFound) {
		// do count the items
		count = [btree entryCount]; // may be expensive
	}
	return count;
}

- (NSUInteger) hash
{
	return (NSUInteger)(LIDFromOID([self oid]) % NSUIntegerMax);
}

- (BOOL) isEqual: (id) other
{
	if (self == other) return YES;
	if (![other respondsToSelector: @selector(oid)]) {
		return NO;
	}
	
	return [self oid] == [other oid];
}

- (NSString*) description
{
	return [NSString stringWithFormat: @"<%@ 0x%x> with %u items.", [self class], self, [self count]];
}


@end

@implementation OPLargePersistentSetArray

- (id) initWithPersistentSet: (OPLargePersistentSet*) aSet
{
	int error = 0;
	pSet = aSet; // non-retained
	arrayCursor = [[pSet btree] newCursorWithError: &error];
	cursorPosition = NSNotFound;
	return self;
}

- (NSUInteger) cursorPosition
{
	return cursorPosition;
}

- (void) forgetSet
{
	pSet = nil;
}

- (void) noteEntryAddedWithKeyBytes: (const char*) keyBytes length: (i64) keyLength
{
	cursorPosition = NSNotFound;
//	int error = 0; 
//	i64 cursorKeyLength = [arrayCursor currentEntryKeyLengthError: &error];
//	char cursorKeyBytes[cursorKeyLength];	
//	[arrayCursor getCurrentEntryKeyBytes: cursorKeyBytes length: cursorKeyLength offset: 0];
//	
//	// compare the keys. If key < cursorKey, adjust cursorPosition:
//	int cmp = [arrayCursor compareFunction](NULL, cursorKeyLength, cursorKeyBytes, keyLength, keyBytes);
//	if (cmp > 0)
//	{
//		cursorPosition++;
//	}
}


- (void) noteEntryRemovedWithKeyBytes: (const char*) keyBytes length: (i64) keyLength
{
	cursorPosition = NSNotFound;

//	int error = 0; 
//	i64 cursorKeyLength = [arrayCursor currentEntryKeyLengthError: &error];
//	char cursorKeyBytes[cursorKeyLength];	
//	[arrayCursor getCurrentEntryKeyBytes: cursorKeyBytes length: cursorKeyLength offset: 0];
//	
//	// compare the keys. If key < cursorKey, adjust cursorPosition:
//	int cmp = [arrayCursor compareFunction](NULL, cursorKeyLength, cursorKeyBytes, keyLength, keyBytes);
//	if (cmp > 0) {
//		if (cursorPosition > 0) {
//			cursorPosition--;
//		} else {
//			// Make sure, cursor is undefined, if the cursor element has been deleted.
//			cursorPosition = NSNotFound;
//		}
//	}
}

- (void) positionCursorToIndex: (NSUInteger) index
{
	int error = 0;
	//NSLog(@"Should position cursor to index: %u (from %u)", index, cursorPosition);
	if (cursorPosition == NSNotFound || ! [arrayCursor isValid]) {
		//NSLog(@"Resetting cursor (valid = %u)", [arrayCursor isValid]);

		error = [arrayCursor moveToFirst];
		NSAssert1(error == 0, @"Unable to position to index %u. No entries?", index);			
		cursorPosition = 0;
	}
	
	while (cursorPosition<index) {
		error = [arrayCursor moveToNext]; cursorPosition++;
		i64 keyLength = [arrayCursor currentEntryKeyLengthError: &error];
		NSAssert1(keyLength > 0, @"invalid (empty key) btree entry (error %u).", error);
		if (error) NSLog(@"Moved cursor forward to %u, error? %u", cursorPosition, error);
	}
	while (cursorPosition>index) {
		error = [arrayCursor moveToPrevious]; cursorPosition--;
		i64 keyLength = [arrayCursor currentEntryKeyLengthError: &error];
		NSAssert1(keyLength > 0, @"invalid (empty key) btree entry (error %u).", error);
		if (error) NSLog(@"Moved cursor back to %u, error? %u", cursorPosition, error);
	}
	NSAssert1(cursorPosition == index, @"Moving the cursor to position %u failed.", index);
}

- (OID) oidAtIndex: (NSUInteger) index
{
	//NSLog(@"objectAtIndex: %u", index);
	
	NSParameterAssert(index < [pSet count]);
	[self positionCursorToIndex: index];
	
	OID oid = NILOID;
	int error = 0; 
	i64 keyLength = [arrayCursor currentEntryKeyLengthError: &error];
	NSAssert2(keyLength >= sizeof(OID), @"Not enough key data (%u bytes) found (error %d).", keyLength, error);
	
	error = [arrayCursor getCurrentEntryKeyBytes: &oid length: sizeof(OID) offset: keyLength-sizeof(OID)];
	oid = NSSwapBigLongLongToHost(oid);
	return oid;
}

- (NSUInteger)indexOfOID: (OID) anOID
{
	NSUInteger count = self.count;
	
	for (NSUInteger i = 0; i < count; i++)
	{
		if ([self oidAtIndex:i] == anOID)
		{
			return i;
		}
	}
	
	return NSNotFound;
}

- (NSUInteger) indexOfObjectIdenticalTo: (id) other
{
	return [self indexOfOID: [other oid]];
}

- (id) objectAtIndex: (NSUInteger) index
{
	//NSLog(@"%@ requesting objectAtIndex: %u", pSet, index);
	OID oid = [self oidAtIndex:index];
	id result = [[pSet context] objectForOID: oid];
	NSAssert3(result != nil, @"Warning: <OPLargePersistentSetArray 0x%x> objectAtIndex: %u is a dangling reference to %llx. Returning nil.", self, index, oid);
	return result;
}


- (NSUInteger) count
{
	return [pSet count];
}

- (NSEnumerator*) objectEnumerator
{
	return [[[OPLargePersistentSetArrayEnumerator alloc] initWithPersistentSet: pSet] autorelease];
}

- (OPLargePersistentSet*) pSet
{
	return pSet;
}

- (NSString*) description
{
	return [NSString stringWithFormat: @"<%@ 0x%x, cursor at %u/%u>", [self class], self, cursorPosition, [self count]];
}

- (void) dealloc
{
	[arrayCursor release];
	[super dealloc];
}

@end

@implementation OPLargePersistentSetArrayEnumerator

- (id) initWithPersistentSet: (OPLargePersistentSet*) theSet
{
	pSet = [theSet retain];
	array = [(OPLargePersistentSetArray*)[pSet sortedArray] retain];
	arrayCount = array.count;
	changeCount = pSet->changeCount;
	return self;
}

- (void) dealloc
{
	[pSet release];
	[array release];
	[super dealloc];
}

- (id) nextObject
{
	id result = nil;
	if (changeCount != pSet->changeCount)
	{
		NSAssert(changeCount == pSet->changeCount, @"set/array mutated during enumeration.");
	}
	if (nextIndex < arrayCount) {
		//NSLog(@"enumerating index %u/%u", nextIndex, arrayCount);
		result = [array objectAtIndex: nextIndex];
		nextIndex++;
	}
	return result;
}

@end
