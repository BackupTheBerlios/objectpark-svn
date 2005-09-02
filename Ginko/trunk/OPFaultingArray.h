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

@interface OPFaultingArray : NSObject {
	OID* data;
	unsigned count,capacity;
	Class elementClass;
	NSString* sortKey; // the key to sort the array. may be null
	int (*compare)(id, id) ;
}

+ (id) array;
- (id) initWithCapacity: (unsigned) newCapacity;

- (unsigned) count;

- (OID) oidAtIndex: (unsigned) index;
- (id) objectAtIndex: (unsigned) anIndex;
- (unsigned) indexOfObject: (OPPersistentObject*) anObject;
- (void) removeObject: (OPPersistentObject*) anObject;


- (void) addOid: (OID) anOid;
- (void) addObject: (OPPersistentObject*) anObject;
- (void) replaceOidAtIndex: (unsigned) anIndex withOid: (OID) anInt;

@end
