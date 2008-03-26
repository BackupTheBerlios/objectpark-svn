//
//  GIMessageGroupOutlineViewController.h
//  Gina
//
//  Created by Axel Katerbau on 07.03.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OPOutlineViewController.h"

@class GIHierarchyNode;

@interface GIMessageGroupOutlineViewController : OPOutlineViewController 
{

}

- (void)deleteHierarchyNode:(GIHierarchyNode *)aNode;

@end
