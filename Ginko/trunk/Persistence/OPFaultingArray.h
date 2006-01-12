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
	char* data;
	unsigned count; // number of objects contained
	unsigned capacity; // max number of objects without reallocing
	unsigned entrySize; // size of a single entry
	Class elementClass; // OPPersistentObject subclass
	NSString* sortKey; // The key to sort the array. May be null.
	//int (*compare)(id, id, OPFaultingArray*);
	BOOL needsSorting;
}

+ (id) array;
- (id) initWithCapacity: (unsigned) newCapacity;

- (unsigned) count;
- (OPPersistentObjectContext*) context;
- (id) lastObject;


- (OID) oidAtIndex: (unsigned) index;
- (id) objectAtIndex: (unsigned) anIndex;
- (unsigned) indexOfObject: (OPPersistentObject*) anObject;
- (BOOL) containsObject: (OPPersistentObject*) anObject;
- (void) removeObject: (OPPersistentObject*) anObject;
- (void) removeObjectAtIndex: (unsigned) index;
- (void) setSortKey: (NSString*) newSortKey;
- (void) setElementClass: (Class) eClass;


- (void) addOid: (OID) oid sortObject: (id) sortObject;
- (void) addObject: (OPPersistentObject*) anObject;
//- (void) replaceOidAtIndex: (unsigned) anIndex withOid: (OID) anInt;

- (NSEnumerator*) objectEnumerator;
- (void) makeObjectsPerformSelector: (SEL) selector;

@end
