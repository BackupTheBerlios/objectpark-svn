//
//  GICommentTreeView.h
//  Gina
//
//  Created by Axel Katerbau on 07.10.06.
//  Copyright 2006 Objectpark Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GIMatrixWithKeyboardSupport.h"

@class GIThread;
@class GIMessage;

@interface GICommentTreeView : GIMatrixWithKeyboardSupport 
{
	GIThread *thread;
	NSMutableDictionary *commentsCache;
    NSMutableArray *border; // helper for comment tree creation

	id selectedMessageOrThread;
    id observedObjectForSelectedMessageOrThread;
    NSString *observedKeyPathForSelectedMessageOrThread;
}

- (GIThread *)thread;
- (void)setThread:(GIThread *)aThread;
- (GIMessage *)selectedMessage;
- (void)setSelectedMessageOrThread:(id)anObject;
- (id)selectedMessageOrThread;
- (void)updateCommentTree:(BOOL)rebuildThread;

- (IBAction)navigateUpInMatrix:(id)sender;
- (IBAction)navigateDownInMatrix:(id)sender;
- (IBAction)navigateLeftInMatrix:(id)sender;
- (IBAction)navigateRightInMatrix:(id)sender;

@end
