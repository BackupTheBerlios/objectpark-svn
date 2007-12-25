//
//  OPPersistentStringDictionary.m
//  PersistenceKit-Test
//
//  Created by Dirk Theisen on 18.12.07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "OPPersistentStringDictionary.h"
#import "OPPersistentObjectContext.h"

@interface OPPersistentStringDictionaryEnumerator : NSEnumerator {
	OPPersistentStringDictionary* dict;
	NSUInteger changeCount;
	BOOL enumerateKeys;
	OPBTreeCursor* cursor;
}

- (id) initWithPersistentDict: (OPPersistentStringDictionary*) dict keys: (BOOL) getKeys;

@end



@implementation OPPersistentStringDictionary

- (NSEnumerator*) objectEnumerator
{
	return [[[OPPersistentStringDictionaryEnumerator alloc] initWithPersistentDict: self keys: NO] autorelease];
}

- (NSEnumerator*) keyEnumerator
{
	return [[[OPPersistentStringDictionaryEnumerator alloc] initWithPersistentDict: self keys: YES] autorelease];
}

- (NSUInteger) count
/*" Can be slow, initial invocation does a table scan. "*/
{
	if (count == NSNotFound) {
		// do count the items
		count = [btree entryCount]; // may be expensive
	}
	return count;
}

- (OPPersistentObjectContext*) context
{
	return [OPPersistentObjectContext defaultContext];
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

+ (BOOL) cachesAllObjects
{
	return NO;
}

+ (BOOL) canPersist
{
	return YES;
}

- (Class) classForCoder
{
	return [self class];
}

- (id) init
{
	count = NSNotFound;
	return self;
}

- (OPBTree*) btree
{
	if (!btree) {
		btree = [[OPBTree alloc] initWithCompareFunctionName: nil withRoot: 0 inDatabase: [[self context] database] flags: 0]; // only used for new objects, also set in -initWithCoder.
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

- (void) setObject: (id) object forKey: (id) key
{
	NSParameterAssert([key isKindOfClass: [NSString class]]);
	OID objectOID = [(OPPersistentObject*)object oid];
	//@synchronized(setCursor) {
	const void* keyBytes = [(NSString*)key UTF8String];
	i64 keyLength = strlen(keyBytes);
	int pos = [[self setterCursor] moveToKeyBytes: keyBytes length: keyLength error: NULL];
	if (pos == 0) {
		// We found an entry under the given string key.
		// Check, of the entry is already present by also comparing the value:
		OID oidFound = [[self setterCursor] currentEntryIntValue];
		if (oidFound != objectOID) {
			changeCount++;
			[[self setterCursor] deleteCurrentEntry];
			[[self setterCursor] insertValueBytes: &objectOID ofLength: sizeof(OID)
									  forKeyBytes: keyBytes ofLength: keyLength isAppend: NO];
		} else {
			// nothing to do, anObject already present
			NSLog(@"Ignoring addition of existing key/value pair to persistent string dictionary.");
		}
	} else {	
		// We did not find key, so insert the given key/value pair:
		changeCount++;
		
		[self willChangeValueForKey: @"count"];
		[[self setterCursor] insertValueBytes: &objectOID ofLength: sizeof(OID)
								  forKeyBytes: keyBytes ofLength: keyLength isAppend: NO];
		if (count!=NSNotFound) count++;
		[self didChangeValueForKey: @"count"];
	} 
}

- (id) objectForKey: (id) key
{
	NSParameterAssert([key isKindOfClass: [NSString class]]);
	const void* keyBytes = [(NSString*)key UTF8String];
	i64 keyLength = strlen(keyBytes);
	OPPersistentObject* result = nil;
	int pos = [[self setterCursor] moveToKeyBytes: keyBytes length: keyLength error: NULL];
	if (pos == 0) {
		// We found a value the key given. Extract the oid:
		OID objectOID = [[self setterCursor] currentEntryIntValue];
		result = [[self context] objectForOID: objectOID];
	}	
	return result;
}

- (void) removeObjectForKey: (id) key
{
	NSParameterAssert([key isKindOfClass: [NSString class]]);
	const void* keyBytes = [(NSString*)key UTF8String];
	i64 keyLength = strlen(keyBytes);
	int pos = [[self setterCursor] moveToKeyBytes: keyBytes length: keyLength error: NULL];
	if (pos == 0) {
		// We found an entry under the given string key.
		[self willChangeValueForKey: @"count"];
		if (count!=NSNotFound) count--;
		changeCount++;
		[[self setterCursor] deleteCurrentEntry];
		[self didChangeValueForKey: @"count"];
	}
}


- (id) initWithCoder: (NSCoder*) coder
{
	int rootPage = [coder decodeInt32ForKey: @"BTreeRootPage"];

	
	btree = [[OPBTree alloc] initWithCompareFunctionName: nil 
												withRoot: rootPage 
											  inDatabase: [[self context] database]];
	
	count = NSNotFound;
	return self;
}

- (void) encodeWithCoder: (NSCoder*) coder
{
	[coder encodeInt: [btree rootPage] forKey: @"BTreeRootPage"];
}


@end


@implementation OPPersistentStringDictionaryEnumerator

- (id) initWithPersistentDict: (OPPersistentStringDictionary*) theDict 
						 keys: (BOOL) getKeys;
{
	dict = [theDict retain];
	changeCount = dict->changeCount;
	enumerateKeys = getKeys;
	return self;
}

- (void) dealloc
{
	[dict release];
	[super dealloc];
}

- (id) nextObject
{
	id result = nil;
	NSAssert(changeCount == dict->changeCount, @"set/array mutated during enumeration.");
	cursor;
	return result;
}

@end