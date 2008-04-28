//
//  GIHierarchyNode.h
//  BTreeLite
//
//  Created by Dirk Theisen on 07.11.07.
//  Copyright 2007 Dirk Theisen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OPPersistentObject.h"

@class OPFaultingArray;

@interface GIHierarchyNode : OPPersistentObject 
{
	NSString *name;
	OPFaultingArray *children;
}

@property (readwrite, copy) NSString *name;
@property (readonly, retain) OPFaultingArray *children;

- (void) insertObject: (GIHierarchyNode*) node inChildrenAtIndex: (NSUInteger) index;
- (BOOL) isDeletable;

@end

@interface GIHierarchyNode (MessageGroupHierarchy)

+ (id) messageGroupHierarchyRootNode;
+ (void) setMessageGroupHierarchyRootNode: (GIHierarchyNode*) rootNode;

+ (id) newWithName:(NSString *)aName atHierarchyNode: (GIHierarchyNode*) aNode atIndex: (int) anIndex;
+ (GIHierarchyNode*) findHierarchyNode: (id) searchedNode startingWithHierarchyNode: (GIHierarchyNode*) startNode;
- (GIHierarchyNode*) parentNode;

@end

extern NSString *GIHierarchyChangedNotification;