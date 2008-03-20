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
//#import "GIMessageGroupTreeController.h"
#import "GIMainWindow.h"

@class GIMessageGroup;
@class GITextView;
@class GIThreadOutlineViewController;
@class OPOutlineViewController;
@class GISplitView;

@interface GIMainWindowController : NSWindowController 
{
	IBOutlet OPOutlineViewController *messageGroupsController;
	IBOutlet GIThreadOutlineViewController *threadsController;
	IBOutlet GICommentTreeView *commentTreeView;
	IBOutlet GIOutlineViewWithThreadColoring *threadsOutlineView;
	IBOutlet NSOutlineView *groupsOutlineView;
	IBOutlet GISplitView *threadMailSplitter;
	IBOutlet NSSplitView *mailTreeSplitter;
	IBOutlet GITextView *messageTextView;
	IBOutlet NSWindow *messageGroupRenameWindow;
	IBOutlet NSTextField *messageGroupNameField;
	
	NSArray *selectedThreads;
	
	/* Binding stuff */
	id observedObjectForSelectedThreads;
	NSString *observedKeyPathForSelectedThreads;
}

@property (readonly) OPOutlineViewController* messageGroupsController;
@property (retain) NSArray *selectedThreads;

- (IBAction) commentTreeSelectionChanged: (id) sender;
- (IBAction) groupTreeSelectionChanged: (id) sender;

/*" Message creation actions "*/
- (IBAction)newMessage:(id)sender;

/*" Message meta info manipulation "*/
- (IBAction)markAsRead:(id)sender;
- (IBAction)markAsUnread:(id)sender;
- (IBAction)toggleRead:(id)sender;

/*" Message Group Actions "*/
- (IBAction)addNewMessageGroup:(id)sender;
- (IBAction)renameMessageGroup:(id)sender;
- (IBAction)doRenameMessageGroup:(id)sender;
- (IBAction)cancelRenameMessageGroup:(id)sender;
	
- (void) showMessage: (GIMessage*) message;

- (void)setThreadsOnlyMode;
- (BOOL)isShowingThreadsOnly;

- (void)performSetSeenBehaviorForMessage:(GIMessage *)aMessage;

@end

@interface GIMainWindowController (OutlineViewDelegateAndActions)

- (IBAction)threadsDoubleAction:(id)sender;

@end

@interface GIMainWindowController (GeneralBindings)

- (NSArray*) messageGroupHierarchyRootNode;

@end
