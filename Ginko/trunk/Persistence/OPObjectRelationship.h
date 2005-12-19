//
//  OPObjectRelationship.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 14.12.05.
//  Copyright 2005 The Objectpark Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OPClassDescription.h"

@class OPFaultingArray;
/*" Object describing a n:m relation between two persistent objects. Used to keep track of changes to n:m relationships. There is one container for deleted and one for inserted/changed relations. "*/

@interface OPObjectRelationship : NSObject {
	
	NSString* firstRelationshipName;
	NSString* secondRelationshipName;
	
	NSMutableSet* addedRelations;
	NSMutableSet* removedRelations;
}

- (id) initWithRelationshipNames: (NSString*) firstName : (NSString*) secondName;

- (NSEnumerator*) removedRelationsEnumerator;
- (NSEnumerator*) addedRelationsEnumerator;

- (void) addRelationNamed: (NSString*) relationName 
					 from: (OPPersistentObject*) sourceObject
					   to: (OPPersistentObject*) targetObject;


- (void) updateRelationshipNamed: (NSString*) relationName 
							from: (OPPersistentObject*) anObject 
						  values: (OPFaultingArray*) array;

- (void) removeRelationNamed: (NSString*) relationName 
						from: (OPPersistentObject*) sourceObject
						  to: (OPPersistentObject*) targetObject;


@end

