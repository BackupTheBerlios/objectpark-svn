//
//  GIThreadTreeController.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 29.10.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OPPersistence.h"

@class GIThread;
@class GIMessage;
@class GIMessageGroup;

@interface GIThreadTreeController : NSTreeController 
{
	NSArray *cachedThreadTreeSelectionIndexPaths;
	OID cacheSelectionIndexPathsGroupOid;
}

- (NSArray *)selectedMessages;
- (BOOL)selectionHasUnreadMessages;
- (BOOL)selectionHasReadMessages;

- (void)rearrangeSelectedNodes;

- (NSInteger)indexOfThread:(GIThread *)aThread;
- (NSInteger)indexOfMessage:(GIMessage *)aMessage inThreadAtIndex:(NSInteger)threadIndex;

- (void)rememberThreadSelectionForGroup:(GIMessageGroup *)group;
- (NSArray *)recallThreadSelectionForGroup:(GIMessageGroup *)group;
- (void)invalidateThreadSelectionCache;

@end
