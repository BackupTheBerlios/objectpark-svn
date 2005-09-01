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
}

+ (id) array;
- (id) initWithCapacity: (unsigned) newCapacity;

- (OID) oidAtIndex: (unsigned) index;
- (void) addOids: (OID*) intArray count: (unsigned) numOidssToAdd;
- (void) addOid: (OID) anOid;
- (void) addObject: (OPPersistentObject*) anObject;
- (void) replaceOidAtIndex: (unsigned) anIndex withOid: (OID) anInt;

@end
