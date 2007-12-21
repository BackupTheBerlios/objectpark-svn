//
//  OPPersistentSet.h
//  BTreeLite
//
//  Created by Dirk Theisen on 15.11.07.
//  Copyright 2007 Dirk Theisen. All rights reserved.
//

#import "OPPersistentObject.h"
#import "OPDBLite.h"

@class OPPersistentSetArray;

/*" Backed directly by a btree "*/
@interface OPPersistentSet : NSMutableSet <NSCoding> {
	NSString* sortKeyPath;
	OPBTree* btree;
	OPBTreeCursor* setterCursor;
	NSUInteger count;
	OPPersistentSetArray* array;
	
	@public 
	NSUInteger changeCount; // increased on every add/remove; do not change from outside
}

@property (copy) NSString* sortKeyPath;

- (OPPersistentObjectContext*) context;

- (NSArray*) sortedArray;

@end
