//
//  OPPersistentSet.h
//  BTreeLite
//
//  Created by Dirk Theisen on 15.11.07.
//  Copyright 2007 Dirk Theisen. All rights reserved.
//

#import "OPPersistentObject.h"
#import "OPDBLite.h"

@class OPPersistentSet;

@interface OPPersistentSetArray : NSArray {
@public
	OPPersistentSet* pSet;
	OPBTreeCursor* arrayCursor;
	NSUInteger cursorPosition;
}

@property (readonly) OPPersistentSet* pSet;
@property (readonly) NSUInteger cursorPosition;

- (id) initWithPersistentSet: (OPPersistentSet*) aSet;
- (void) forgetSet;

- (void) noteEntryAddedWithKeyBytes: (const char*) keyBytes length: (i64) keyLength;
- (void) noteEntryRemovedWithKeyBytes: (const char*) keyBytes length: (i64) keyLength;

- (NSUInteger)indexOfOid:(OID)anOid;

@end

/*" Backed directly by a btree "*/
@interface OPPersistentSet : NSMutableSet <OPPersisting> {
	NSString* sortKeyPath;
	OPBTree* btree;
	OPBTreeCursor* setterCursor;
	NSUInteger count;
	OPPersistentSetArray* array;
	OID oid;
	
	@public 
	NSUInteger changeCount; // increased on every add/remove; do not change from outside
}

@property (copy) NSString* sortKeyPath;

- (OPPersistentObjectContext*) context;

- (NSArray*) sortedArray;

@end

