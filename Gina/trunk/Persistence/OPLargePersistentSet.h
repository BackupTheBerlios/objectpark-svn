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

@interface OPLargePersistentSetArray : NSArray {
@public
	OPLargePersistentSet* pSet;
	OPBTreeCursor* arrayCursor;
	NSUInteger cursorPosition;
}

@property (readonly) OPLargePersistentSet* pSet;
@property (readonly) NSUInteger cursorPosition;

- (id) initWithPersistentSet: (OPLargePersistentSet*) aSet;
//- (void) forgetSet;

- (void) noteEntryAddedWithKeyBytes: (const char*) keyBytes length: (i64) keyLength;
- (void) noteEntryRemovedWithKeyBytes: (const char*) keyBytes length: (i64) keyLength;

- (void) willChangeSortKeyValueForObject: (id) object;
- (void) didChangeSortKeyValueForObject: (id) object;

@end

/*" Backed directly by a btree "*/
@interface OPLargePersistentSet : NSMutableSet <OPPersisting> {
	NSString* sortKeyPath;
	OPBTree* btree;
	OPBTreeCursor* setterCursor;
	NSUInteger count;
	OPLargePersistentSetArray* array;
	OID oid;
	
	@public 
	NSUInteger changeCount; // increased on every add/remove; do not change from outside
}

@property (copy) NSString* sortKeyPath;

- (BOOL) containsObjectWithOID: (OID) oid sortKeyValue: (id) sortKeyValue;

- (OPPersistentObjectContext*) context;

- (OPLargePersistentSetArray*) sortedArray;

- (void) addPrimitiveObject: (id) anObject;
- (void) removePrimitiveObject: (id) anObject;

- (OPBTree*) btree; // private

@end

