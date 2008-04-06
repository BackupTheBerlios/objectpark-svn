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
@class GIMessageGroupOutlineViewController;
@class GISplitView;

@interface GIMainWindowController : NSWindowController 
{
	IBOutlet GIMessageGroupOutlineViewController *messageGroupsController;
	IBOutlet GIThreadOutlineViewController *threadsController;
	IBOutlet GICommentTreeView *commentTreeView;
	IBOutlet GIOutlineViewWithThreadColoring *threadsOutlineView;
	IBOutlet NSOutlineView *groupsOutlineView;
	IBOutlet GISplitView *threadMailSplitter;
	IBOutlet GISplitView *mailTreeSplitter;
	IBOutlet GISplitView *verticalSplitter;
	IBOutlet GITextView *messageTextView;
	IBOutlet NSWindow *messageGroupRenameWindow;
	IBOutlet NSTextField *messageGroupNameField;
	IBOutlet NSScrollView *progressInfoScrollView;
	IBOutlet NSBox *searchResultView;
	IBOutlet NSScrollView *regularThreadsView;
	
	BOOL searchMode;
	
	CGFloat progressInfoHeight;
	
	NSArray *selectedThreads;
	
	/* Binding stuff */
	id observedObjectForSelectedThreads;
	NSString *observedKeyPathForSelectedThreads;
	
	NSMetadataQuery *query;
}

@property (readonly) GIMessageGroupOutlineViewController *messageGroupsController;
@property (retain) NSArray *selectedThreads;
@property (readonly) NSMetadataQuery *query;

- (IBAction) commentTreeSelectionChanged: (id) sender;
- (IBAction) groupTreeSelectionChanged: (id) sender;

/*" Message creation actions "*/
- (IBAction)newMessage:(id)sender;
- (IBAction)replyAll:(id)sender;
- (IBAction)replySender:(id)sender;
- (IBAction)followup:(id)sender;
- (IBAction)replyDefault:(id)sender;
- (IBAction)forward:(id)sender;

/*" Message meta info manipulation "*/
- (IBAction)markAsRead:(id)sender;
- (IBAction)markAsUnread:(id)sender;
- (IBAction)toggleRead:(id)sender;

/*" Message Group Actions "*/
- (IBAction)addNewMessageGroup:(id)sender;
- (IBAction)addNewFolder:(id)sender;
- (IBAction)rename:(id)sender;
- (IBAction)doRename:(id)sender;
- (IBAction)cancelRename:(id)sender;
- (IBAction)delete:(id)sender;
	
- (void)showMessage:(GIMessage *)message;
- (IBAction)search:(id)sender;

- (void)setThreadsOnlyMode;
- (BOOL)isShowingThreadsOnly;

- (void)performSetSeenBehaviorForMessage:(GIMessage *)aMessage;

- (GIMessageGroup *)selectedGroup;

@end

@interface GIMainWindowController (OutlineViewDelegateAndActions)

- (IBAction)threadsDoubleAction:(id)sender;

@end

@interface GIMainWindowController (GeneralBindings)

- (NSArray*) messageGroupHierarchyRootNode;

@end
