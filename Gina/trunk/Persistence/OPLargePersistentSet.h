//
//  OPPersistentSet.h
//  BTreeLite
//
//  Created by Dirk Theisen on 15.11.07.
//  Copyright 2007 Dirk Theisen. All rights reserved.
//

#import "OPPersistentObject.h"
#import "OPDBLite.h"

@class OPLargePersistentSet;

@interface OPPersistentSetArray : NSArray {
@public
	OPLargePersistentSet* pSet;
	OPBTreeCursor* arrayCursor;
	NSUInteger cursorPosition;
}

@property (readonly) OPLargePersistentSet* pSet;
@property (readonly) NSUInteger cursorPosition;

- (id) initWithPersistentSet: (OPLargePersistentSet*) aSet;
- (void) forgetSet;

- (void) noteEntryAddedWithKeyBytes: (const char*) keyBytes length: (i64) keyLength;
- (void) noteEntryRemovedWithKeyBytes: (const char*) keyBytes length: (i64) keyLength;

@end

/*" Backed directly by a btree "*/
@interface OPLargePersistentSet : NSMutableSet <OPPersisting> {
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

- (BOOL) containsObjectWithOID: (OID) oid sortKeyValue: (id) sortKeyValue;

- (OPPersistentObjectContext*) context;

- (NSArray*) sortedArray;

@end

