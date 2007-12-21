//
//  GIMainWindowController.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 12.10.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GICommentTreeView.h"
#import "GIOutlineViewWithThreadColoring.h"

@class GIMessageGroup;
@class GITextView;

@interface GIMainWindowController : NSWindowController 
{
	IBOutlet NSTreeController *messageGroupTreeController;
//	IBOutlet GIThreadTreeController *threadTreeController;
	IBOutlet GICommentTreeView *commentTreeView;
	IBOutlet GIOutlineViewWithThreadColoring *threadsOutlineView;
	IBOutlet NSSplitView *threadMailSplitter;
	IBOutlet NSSplitView *mailTreeSplitter;
	IBOutlet GITextView *messageTextView;
}

- (IBAction)commentTreeSelectionChanged:(id)sender;

/*" Message meta info manipulation "*/
- (IBAction)markAsRead:(id)sender;
- (IBAction)markAsUnread:(id)sender;
- (IBAction)toggleRead:(id)sender;

@end
