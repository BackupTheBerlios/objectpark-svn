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

#define SEARCHRANGE_ALLMESSAGEGROUPS 0
#define SEARCHRANGE_SELECTEDGROUP 1

#define SEARCHFIELDS_ALL 0
#define SEARCHFIELDS_AUTHOR 1
#define SEARCHFIELDS_RECIPIENTS 2
#define SEARCHFIELDS_SUBJECT 3

@class GIMessageGroup;
@class GITextView;
@class GIThreadOutlineViewController;
@class GIMessageGroupOutlineViewController;
@class GISplitView;
@class WebView;
@class GIProfile;

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
	IBOutlet NSScrollView *messageTextScrollView;
	IBOutlet GITextView *messageTextView;
	IBOutlet NSWindow *messageGroupRenameWindow;
	IBOutlet NSTextField *messageGroupNameField;
	IBOutlet NSScrollView *progressInfoScrollView;
	IBOutlet NSBox *searchResultView;
	IBOutlet NSScrollView *regularThreadsView;
	IBOutlet NSTableView *searchResultTableView;
	IBOutlet NSSearchField *searchField;
	IBOutlet NSArrayController *searchResultsArrayController;
	IBOutlet WebView *messageWebView;
	IBOutlet NSWindow *redirectSheet;
	
	BOOL searchMode;
	
	CGFloat progressInfoHeight;
	
	NSArray *selectedThreads;
	NSArray *selectedSearchResults;
	
	GIMessage *selectedMessageInSearchMode;
	
	/* Binding stuff */
	id observedObjectForSelectedThreads;
	NSString *observedKeyPathForSelectedThreads;
	id observedObjectForSelectedSearchResults;
	NSString *observedKeyPathForSelectedSearchResults;
	
	NSMetadataQuery *query;
	
	GIProfile *redirectProfile;
	NSArray *resentTo;
	NSArray *resentCc;
	NSArray *resentBcc;
}

@property (readonly) GIMessageGroupOutlineViewController *messageGroupsController;
@property (retain) NSArray *selectedThreads;
@property (retain) NSArray *selectedSearchResults;
@property (readonly) NSMetadataQuery *query;
@property (readonly) NSTableView *searchResultTableView;
@property (retain) GIMessage *selectedMessageInSearchMode;
@property (retain) GIProfile *redirectProfile;
@property (retain) NSArray *resentTo;
@property (retain) NSArray *resentCc;
@property (retain) NSArray *resentBcc;

- (void)showMessage:(GIMessage *)message;
- (BOOL)isShowingMessageOnly;

- (void)setThreadsOnlyMode;
- (BOOL)isShowingThreadsOnly;
- (BOOL)isShowingMessageOnly;
- (void)showMessageOnly;

- (void)performSetSeenBehaviorForMessage:(GIMessage *)aMessage;

- (GIMessageGroup *)selectedGroup;

@end

@interface GIMainWindowController (Actions)

/*" Adding hierarchy objects "*/
- (IBAction)addNewMessageGroup:(id)sender;
- (IBAction)addNewFolder:(id)sender;

/*" Deleting hierarchy objects "*/
- (IBAction)delete:(id)sender;

/*" Renaming hierarchy objects "*/
- (IBAction)rename:(id)sender;
- (IBAction)doRename:(id)sender;
- (IBAction)cancelRename:(id)sender;

/*" Message creation actions "*/
- (IBAction)newMessage:(id)sender;
- (IBAction)replyAll:(id)sender;
- (IBAction)replySender:(id)sender;
- (IBAction)followup:(id)sender;
- (IBAction)replyDefault:(id)sender;
- (IBAction)forward:(id)sender;
- (IBAction)redirect:(id)sender;

/*" Message meta info manipulation "*/
- (IBAction)markAsRead:(id)sender;
- (IBAction)markAsUnread:(id)sender;
- (IBAction)toggleRead:(id)sender;

/*" Progress info view handling "*/
- (BOOL)progressInfoVisible;
- (IBAction)toggleProgressInfo:(id)sender;

/*" Miscellaneous "*/
- (IBAction)commentTreeSelectionChanged:(id)sender;
- (IBAction)messageGroupSelectionChanged:(id)sender;

@end

@interface GIMainWindowController (Search)

@property BOOL searchMode;

- (IBAction)search:(id)sender;
- (IBAction)searchRangeChanged:(id)sender;

@end

@interface GIMainWindowController (OutlineViewActions)

- (IBAction)threadsDoubleAction:(id)sender;

@end

@interface GIMainWindowController (GeneralBindings)

- (NSArray*) messageGroupHierarchyRootNode;

@end

@interface GIMainWindowController (MessageRedirect)
- (IBAction)doRedirect:(id)sender;
- (IBAction)cancelRedirect:(id)sender;
@end
