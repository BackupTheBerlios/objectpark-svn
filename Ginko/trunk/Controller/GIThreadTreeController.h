//
//  GIThreadTreeController.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 29.10.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface GIThreadTreeController : NSTreeController 
{

}

- (NSArray *)selectedMessages;
- (BOOL)selectionHasUnreadMessages;
- (BOOL)selectionHasReadMessages;

@end
