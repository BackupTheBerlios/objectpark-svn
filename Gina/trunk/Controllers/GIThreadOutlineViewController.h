//
//  GIThreadOutlineViewController.h
//  Gina
//
//  Created by Axel Katerbau on 08.01.08.
//  Copyright 2008 Objectpark Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OPOutlineViewController.h"

@interface GIThreadOutlineViewController : OPOutlineViewController 
{
	BOOL suspendUpdatesUntilNextReloadData;
}

@property BOOL suspendUpdatesUntilNextReloadData;

- (NSArray *)selectedMessages;
- (BOOL)selectionHasUnreadMessages;
- (BOOL)selectionHasReadMessages;

@end
