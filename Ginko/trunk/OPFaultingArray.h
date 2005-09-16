//
//  OPFaultingArray.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 01.09.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OPPersistenceConstants.h"

@class OPPersistentObject;
@class OPFaultingArray;
@class OPPersistentObjectContext;

@interface OPFaultingArray : NSObject {
	char* data;
	unsigned count,capacity;
	unsigned entrySize;
	Class elementClass;
	NSString* sortKey; // the key to sort the array. may be null
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

@end
