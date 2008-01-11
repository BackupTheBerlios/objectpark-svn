//
//  GIMainWindowController.h
//  Gina
//
//  Created by Axel Katerbau on 12.10.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GICommentTreeView.h"
#import "GIOutlineViewWithThreadColoring.h"
#import "GIMainWindow.h"

@class GIMessageGroup;
@class GITextView;
@class GIThreadOutlineViewController;

@interface GIMainWindowController : NSWindowController 
{
	IBOutlet NSTreeController *messageGroupTreeController;
	IBOutlet GIThreadOutlineViewController *threadsController;
	IBOutlet GICommentTreeView *commentTreeView;
	IBOutlet GIOutlineViewWithThreadColoring *threadsOutlineView;
	IBOutlet NSSplitView *threadMailSplitter;
	IBOutlet NSSplitView *mailTreeSplitter;
	IBOutlet GITextView *messageTextView;
	
	GIMessageGroup *selectedMessageGroup;
	NSArray *selectedThreads;
	
	/* Binding stuff */
	id observedObjectForSelectedThreads;
	NSString *observedKeyPathForSelectedThreads;
}

@property (retain) NSArray *selectedThreads;

- (IBAction)commentTreeSelectionChanged:(id)sender;

/*" Message meta info manipulation "*/
- (IBAction)markAsRead:(id)sender;
- (IBAction)markAsUnread:(id)sender;
- (IBAction)toggleRead:(id)sender;

@end

@interface GIMainWindowController (KeyboardShortcuts) <GIMainWindowDelegate>
@end
