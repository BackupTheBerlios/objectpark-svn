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
	
	OPAttributeDescription* firstAttribute;
	OPAttributeDescription* secondAttribute;
	
	NSMutableSet* addedRelations;
	NSMutableSet* removedRelations;
}

- (id) initWithAttributeDescriptions: (OPAttributeDescription*) firstAttr 
									: (OPAttributeDescription*) secondAttr;

- (NSEnumerator*) removedRelationsEnumerator;
- (NSEnumerator*) addedRelationsEnumerator;

- (OPAttributeDescription*) firstAttributeDescription;
- (OPAttributeDescription*) secondAttributeDescription;

- (NSString*) joinTableName;
- (NSString*) firstColumnName;
- (NSString*) secondColumnName;

- (unsigned) changeCount;


/*" Updating Relations "*/

- (void) addRelationNamed: (NSString*) relationName 
					 from: (OPPersistentObject*) sourceObject
					   to: (OPPersistentObject*) targetObject;

- (void) removeRelationNamed: (NSString*) relationName 
						from: (OPPersistentObject*) sourceObject
						  to: (OPPersistentObject*) targetObject;

- (void) reset;


/*" Redoing Relationship Changes "*/

- (void) updateRelationshipNamed: (NSString*) relationName 
							from: (OPPersistentObject*) anObject 
						  values: (OPFaultingArray*) array;



@end

