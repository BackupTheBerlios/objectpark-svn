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
@class GIMessageGroupTreeController;

@interface GIMainWindowController : NSWindowController 
{
	IBOutlet GIMessageGroupTreeController *messageGroupTreeController;
	IBOutlet GIThreadOutlineViewController *threadsController;
	IBOutlet GICommentTreeView *commentTreeView;
	IBOutlet GIOutlineViewWithThreadColoring *threadsOutlineView;
	IBOutlet NSOutlineView *groupsOutlineView;
	IBOutlet NSSplitView *threadMailSplitter;
	IBOutlet NSSplitView *mailTreeSplitter;
	IBOutlet GITextView *messageTextView;
	
	//GIMessageGroup *selectedMessageGroup;
	NSArray *selectedThreads;
	
	/* Binding stuff */
	id observedObjectForSelectedThreads;
	NSString *observedKeyPathForSelectedThreads;
}

@property (retain) NSArray *selectedThreads;

- (IBAction) commentTreeSelectionChanged: (id) sender;
- (IBAction) groupTreeSelectionChanged: (id) sender;


/*" Message meta info manipulation "*/
- (IBAction)markAsRead:(id)sender;
- (IBAction)markAsUnread:(id)sender;
- (IBAction)toggleRead:(id)sender;

- (void) showMessage: (GIMessage*) message;

- (void)setThreadsOnlyMode;
- (BOOL)isShowingThreadsOnly;

- (void)performSetSeenBehaviorForMessage:(GIMessage *)aMessage;

@end

@interface GIMainWindowController (OutlineViewDelegateAndActions)

- (IBAction)threadsDoubleAction:(id)sender;

@end
