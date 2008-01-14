//
//  GIThreadOutlineViewController.h
//  Gina
//
//  Created by Axel Katerbau on 08.01.08.
//  Copyright 2008 Objectpark Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OPOutlineViewController.h"
#import "GIMessage.h"
#import "GIThread.h"

@interface GIThreadOutlineViewController : OPOutlineViewController 
{
	BOOL suspendUpdatesUntilNextReloadData;
}

@property BOOL suspendUpdatesUntilNextReloadData;

- (NSArray *)selectedMessages;
- (void)setSelectedMessages:(NSArray *)someMessages;

- (BOOL) selectionHasUnreadMessages;
- (BOOL) selectionHasReadMessages;

@end

@interface GIMessage (ThreadViewSupport)
- (GIMessage *)message;
- (NSArray *)threadChildren;
- (id)subjectAndAuthor;
- (NSAttributedString *)messageForDisplay;
- (NSImage *)statusImage;
@end

@interface GIThread (ThreadViewSupport)
- (GIMessage*) message;
- (NSArray*) threadChildren;
- (id) subjectAndAuthor;
- (NSAttributedString*) messageForDisplay;
- (NSAttributedString*) dateForDisplay;
- (NSImage*) statusImage;
@end

