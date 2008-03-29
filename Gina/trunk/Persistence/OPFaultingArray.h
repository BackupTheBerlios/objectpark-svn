//
//  OPFaultingArray.h
//  Gina
//
//  Created by Dirk Theisen on 01.09.05.
//  Copyright 2005 The Objectpark Group. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OPPersistenceConstants.h"

@class OPPersistentObject;
@class OPFaultingArray;
@class OPPersistentObjectContext;

@interface OPFaultingArray : NSMutableArray {
	
	@private
	char* data;
	unsigned count; // number of objects contained
	unsigned capacity; // max number of objects without reallocing
	//OPPersistentObject* parent; // used for KVO and for resolving the context; non-retained!
}

+ (id) array;


- (NSUInteger) count;

- (id) objectAtIndex: (NSUInteger) index;
- (OID) oidAtIndex: (NSUInteger) index;
- (OID) lastOID;

//- (OPPersistentObject*) parent;
//- (void) setParent: (OPPersistentObject*) theParent;


- (id) objectAtIndex: (NSUInteger) anIndex;

- (NSUInteger) indexOfOID: (OID) oid;
- (id) lastObject;

- (void) removeObjectAtIndex: (NSUInteger) index;
- (void) removeLastObject;
- (void) replaceOIDAtIndex: (NSUInteger) anIndex withOID: (OID) anOid;
- (void) replaceObjectAtIndex: (NSUInteger) index withObject: (id) anObject;


- (void) addOID: (OID) oid;
- (void) addObject: (id) anObject;


@end

@interface NSArray (OPPersistence) 

- (BOOL) containsObjectIdenticalTo: (id) object;

@end
