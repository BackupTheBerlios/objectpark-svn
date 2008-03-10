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

@end

@interface GIHierarchyNode (MessageGroupHierarchy)
+ (id)messageGroupHierarchyRootNode;
@end
