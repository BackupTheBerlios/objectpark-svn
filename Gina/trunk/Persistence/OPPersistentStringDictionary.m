//
//  OPPersistentStringDictionary.m
//  PersistenceKit-Test
//
//  Created by Dirk Theisen on 18.12.07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "OPPersistentStringDictionary.h"


@implementation OPPersistentStringDictionary



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
				[context insertObject: (OPPersistentObject*) self];
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
			[[self context] registerObject: (OPPersistentObject*)self];
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
