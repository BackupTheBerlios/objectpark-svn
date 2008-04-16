//
//  OPPersistentStringDictionary.m
//  PersistenceKit-Test
//
//  Created by Dirk Theisen on 18.12.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
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

- (NSUInteger) hash
{
	return (NSUInteger)(LIDFromOID([self oid]) % NSUIntegerMax);
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


- (BOOL) isEqual: (id) other
{
	if (![other respondsToSelector: @selector(oid)]) {
		return NO;
	}
	
	return [self oid] == [other oid];
}


+ (BOOL) cachesAllObjects
{
	return YES;
}


- (Class) classForCoder
{
	return [self class];
}

- (id) init
{
	NSLog(@"Created new String Dictionary 0x%x", self);
	count = NSNotFound;
	return self;
}

- (OPBTree*) btree
{
	if (!btree) {
		OPDBLite* db = [[self context] database];
		btree = [[OPBTree alloc] initWithCompareFunctionName: nil withRoot: 0 inDatabase: db flags: 0]; // only used for new objects, also set in -initWithCoder.
		if (!btree) {
			btree = [[OPBTree alloc] initWithCompareFunctionName: nil withRoot: 0 inDatabase: db flags: 0]; // only used for new objects, also set in -initWithCoder.
			NSAssert1(btree, @"unable to create btree in database %@", db);
		}
	}
	return btree;
}

- (OPBTreeCursor*) setterCursor
{
	if (! setterCursor) {
		int error = SQLITE_OK;
		setterCursor = [[self btree] newCursorWithError: &error];
		if (! setterCursor)
			NSAssert(setterCursor, @"Unable to read from the database.");
	}
	return setterCursor;
}

//- (void) turnIntoFault
//{
//	Class faultClass = [OPPersistentObjectFault class];
//	isa = faultClass;
//}
//
//- (id) initFaultWithContext: (OPPersistentObjectContext*) context oid: (OID) anOID
//{
//	[self turnIntoFault];
//	[self setOID: anOID];
//	return self;
//}

- (void) willRevert
{
	NSLog(@"Reverting %@ 0x%x", [self class], self);
	[setterCursor release]; setterCursor = nil;
	[btree release]; btree = nil;
}

- (void) setObject: (id) object forKey: (id) key
{
//	if (!key)
//	{
//		NSBeep();
//	}
	
	NSParameterAssert(key != nil);
	NSParameterAssert([key isKindOfClass: [NSString class]]);
	OID objectOID = [(OPPersistentObject*)object oid];
	//@synchronized(setCursor) {
	const void* keyBytes = [(NSString*)key UTF8String];
	i64 keyLength = strlen(keyBytes);
	int error = 0;
	int pos = [[self setterCursor] moveToKeyBytes: keyBytes length: keyLength error: &error];
	if (pos == 0) {
		// We found an entry under the given string key.
		// Check, of the entry is already present by also comparing the value:
		OID oidFound = [[self setterCursor] currentEntryIntValue];
		if (oidFound != objectOID) {
			// replace:
			changeCount++;
			[[self setterCursor] deleteCurrentEntry];
			[[self setterCursor] insertIntValue: objectOID forKeyBytes: keyBytes ofLength: keyLength isAppend: NO];
			
		} else {
			// nothing to do, anObject already present
			// if (NSDebugEnabled) NSLog(@"Ignoring addition of existing key/value pair to persistent string dictionary.");
		}
	} else {	
		// We did not find key, so insert the given key/value pair:
		changeCount++;
		
		[self willChangeValueForKey: @"count"];

		[[self setterCursor] insertIntValue: objectOID forKeyBytes: keyBytes ofLength: keyLength isAppend: NO];

		if (count!=NSNotFound) count++;
		[self didChangeValueForKey: @"count"];
	} 
}

- (BOOL) hasUnsavedChanges
{
	return [[[self context] changedObjects] containsObject: self];
}

- (NSString*) description
{
	return [NSString stringWithFormat: @"<%@ 0x%x> with %u entries", [self class], self, self.count];
}

- (NSString*) descriptionWithLocale: (id) locale
{
	return [NSString stringWithFormat: @"<%@ 0x%x> with %u entries", [self class], self, self.count];
}

- (id) objectForKey: (id) key
{	
	if (![key isKindOfClass: [NSString class]])
	{
		NSBeep();
	}
	
	NSParameterAssert(key != nil);
	NSParameterAssert([key isKindOfClass: [NSString class]]);
	const void* keyBytes = [(NSString*)key UTF8String];
	i64 keyLength = strlen(keyBytes);
	int error = SQLITE_OK;
	OPBTreeCursor* theCursor = [self setterCursor];
	OPPersistentObject* result = nil;
	int pos = [theCursor moveToKeyBytes: keyBytes length: keyLength error: &error];
	if (pos == 0) {
		// We found a value the key given. Extract the oid:
		if ([theCursor currentEntryKeyLengthError: NULL] == 0) 
			return nil;
		OID objectOID = [theCursor currentEntryIntValue];
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
											  inDatabase: [[coder context] database]
												   flags: 0];
	
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