//
//  OPFaultingArray.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 01.09.05.
//  Copyright 2005 The Objectpark Group. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OPPersistenceConstants.h"

@class OPPersistentObject;
@class OPFaultingArray;
@class OPPersistentObjectContext;

@interface OPFaultingArray : NSArray {
	
	@private
	char* data;
	unsigned count; // number of objects contained
	unsigned capacity; // max number of objects without reallocing
	unsigned entrySize; // size of a single entry
	Class elementClass; // OPPersistentObject subclass
	NSString* sortKey; // The key to sort the array. May be null.
	//int (*compare)(id, id, OPFaultingArray*);
	BOOL needsSorting;
	
	unsigned lastIndexFound; // todo: optimization: use this as a cache for indexOfObject. Try the cache first. This way, the sequence (containsObject: removeObject: becomes faster)!
}

+ (id) array;
- (id) initWithCapacity: (unsigned) newCapacity;

- (unsigned) count;

- (OID) oidAtIndex: (unsigned) index;
- (id) sortObjectAtIndex: (unsigned) index;
- (OID) lastOid;

- (id) objectAtIndex: (unsigned) anIndex;
- (unsigned) indexOfObject: (OPPersistentObject*) anObject;
- (id) lastObject;
- (BOOL) containsObject: (OPPersistentObject*) anObject;

- (void) removeObject: (OPPersistentObject*) anObject;
- (void) removeObjectAtIndex: (unsigned) index;
- (void) removeLastObject;

- (void) setSortKey: (NSString*) newSortKey;
- (void) setElementClass: (Class) eClass;

- (unsigned) indexOfFirstSortObjectEqualTo: (id) sortObject;
- (void) addOid: (OID) oid sortObject: (id) sortObject;
- (void) addObject: (OPPersistentObject*) anObject;
- (void) updateSortObjectForObject: (id) element;


@end
