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

- (id) initWithCoder: (NSCoder*) coder
{
	int rootPage = [coder decodeInt32ForKey: @"BTreeRootPage"];

	
	btree = [[OPKeyOnlyBTree alloc] initWithCompareFunctionName: nil 
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
