//
//  GIMainWindowController.m
//  Gina
//
//  Created by Axel Katerbau on 12.10.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import "GIMainWindowController.h"
#import "GIThreadOutlineViewController.h"
#import "GIMessageGroupOutlineViewController.h"
#import "GIMessageEditorController.h"
#import "GISplitView.h"
#import "GIUserDefaultsKeys.h"
#import "GITextView.h"

// helper
#import <WebKit/WebKit.h>
#import <Foundation/NSDebug.h>
#import "NSArray+Extensions.h"
#import "NSAttributedString+Extensions.h"
#import "NSString+Extensions.h"

// model stuff
#import "OPPersistentObject.h"
#import "OPPersistentSet.h"

#import "GIThread.h"
#import "GIMessage.h"
#import "GIMessage+Rendering.h"
#import "GIHierarchyNode.h"
#import "GIMessageGroup.h"
#import "GIMessageBase.h"
#import "GIMessageFilter.h"
#import "GIAccount.h"

@implementation GIMainWindowController

@synthesize selectedThreads;
@synthesize selectedSearchResults;
@synthesize messageGroupsController;
@synthesize query;
@synthesize searchResultTableView;
@synthesize selectedMessageInSearchMode;
@synthesize redirectProfile;
@synthesize resentTo;
@synthesize resentCc;
@synthesize resentBcc;

- (GIMessageGroup *)selectedGroup
{
	id result = [messageGroupsController selectedObject];
	if (![result isKindOfClass:[GIMessageGroup class]]) result = nil;
	return result;
}

+ (NSSet *)keyPathsForValuesAffectingSelectedMessageOrThread
{
	return [NSSet setWithObjects:@"selectedThreads", @"selectedSearchResults", @"selectedMessageInSearchMode", nil];
}

- (id)selectedMessageOrThread
{
	if ([self isSearchMode])
	{
		if ([self.selectedSearchResults count] == 1)
		{
			return [[self.selectedSearchResults lastObject] message];
		}
		else
		{
			return self.selectedMessageInSearchMode;
		}
	}
	else
	{
		NSArray *threads = self.selectedThreads;
		if ([threads count] == 1)
		{
			return [threads lastObject];
		}
	}
	
	return nil;	
}

+ (NSSet *)keyPathsForValuesAffectingSelectedMessage
{
	return [NSSet setWithObjects:@"selectedThreads", @"selectedSearchResults", nil];
}

- (GIMessage *)selectedMessage
{
	GIMessage *result = nil;
	
	if ([self isSearchMode])
	{
		if ([self.selectedSearchResults count] == 1)
		{
			result = [(NSMetadataItem *)[self.selectedSearchResults lastObject] message];
		}
	}
	else
	{
		if ([[self selectedThreads] count] == 1)
		{
			result = [(GIThread *)[[self selectedThreads] lastObject] message];
		}
	}
	
	return result;
}

- (NSArray *)selectedMessages
{
	if ([self isSearchMode])
	{
		NSArray *selectedObjects = [searchResultsArrayController selectedObjects];
		NSMutableArray *result = [NSMutableArray arrayWithCapacity:selectedObjects.count];
		
		for (NSMetadataItem *item in selectedObjects)
		{
			[result addObject:[item message]];
		}
		
		return result;
	}
	else
	{
		return [threadsController selectedMessages];
	}
}

- (BOOL)selectionHasUnreadMessages
{
	if ([self isSearchMode])
	{
		NSArray *selectedObjects = [searchResultsArrayController selectedObjects];
		
		for (NSMetadataItem *item in selectedObjects)
		{
			if (![item message].isSeen) return YES;
		}
		return NO;
	}
	else
	{
		return [threadsController selectionHasUnreadMessages];
	}
}

+ (NSSet *)keyPathsForValuesAffectingMessageForDisplay
{
	return [NSSet setWithObject:@"selectedMessageOrThread"];
}

- (NSAttributedString *)messageForDisplay
{
	if (![self isShowingThreadsOnly])
	{
		id selectedObject = self.selectedMessageOrThread;
		
		if (!selectedObject) return [[[NSAttributedString alloc] init] autorelease];
		
		NSAttributedString *result = [selectedObject messageForDisplay];
		//NSLog(@"message for display: %@", [result string]);
		
		return result;
	}
	
	return nil;
}

+ (NSSet *)keyPathsForValuesAffectingWebArchiveForDisplay
{
	return [NSSet setWithObject:@"selectedMessageOrThread"];
}

- (WebArchive *)webArchiveForDisplay
{
	GIMessage *message = self.selectedMessage;
	
	if (!message) return nil;
	
	WebArchive *result = [message.internetMessage webArchive];
	//NSLog(@"message for display: %@", [result string]);
	
	NSLog(@"Web archive = %@", result);
	
	return result;
}


- (id)init
{
	if (self = [self initWithWindowNibName:@"MainWindow"]) {
		
		treeViewHeight = 200; // just some default, improve!
		
		[self retain];
		
		// setting up query:
		query = [[NSMetadataQuery alloc] init];
		[query setSearchScopes:[NSArray arrayWithObjects: /*NSMetadataQueryUserHomeScope*/[[OPPersistentObjectContext defaultContext] transferDataDirectory], nil]];
		
		// setup our Spotlight notifications
		NSNotificationCenter *nf = [NSNotificationCenter defaultCenter];
		[nf addObserver:self selector:@selector(queryNotification:) name:nil object:query];
		
		[query setDelegate:self];
		
		// show window:
		[self window];
	}
	return self;
}

- (void)dealloc
{
	NSLog(@"GIMainWindowController dealloc");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [query release];
	[selectedThreads release];
	[searchResultView release];
	[regularThreadsView release];
	[selectedMessageInSearchMode release];
	[redirectProfile release];
	[resentTo release];
	[resentCc release];
	[resentBcc release];
	
 	[super dealloc];
}

- (void)windowWillClose:(NSNotification *)notification
{
	[self expandDetailView];

	// Store group selection:
	[[NSUserDefaults standardUserDefaults] setObject:[[self.messageGroupsController selectedObject] objectURLString] forKey:@"SelectedGroupURL"];
	
	//NSLog(@"saving group selection %@ ", [self.messageGroupsController selectedObject]);
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	[self unbind:@"selectedThreads"];
	[self unbind:@"selectedSearchResults"];
	[threadsController unbind:@"rootItem"];
	[self unbind:@"selectedMessageOrThread"];
	
	[self autorelease];
}

- (void)windowDidLoad
{
	[searchResultView retain];
	[regularThreadsView retain];
	
	// configure sort keys of search result table view:
	NSSortDescriptor *sortDescriptor = [[[NSSortDescriptor alloc] initWithKey:(NSString *)kMDItemContentCreationDate ascending:YES] autorelease];
	[[searchResultTableView tableColumnWithIdentifier:@"date"] setSortDescriptorPrototype:sortDescriptor];
	
	sortDescriptor = [[[NSSortDescriptor alloc] initWithKey:(NSString *)kMDItemSubject ascending:YES] autorelease];
	[[searchResultTableView tableColumnWithIdentifier:@"subject"] setSortDescriptorPrototype:sortDescriptor];

	sortDescriptor = [[[NSSortDescriptor alloc] initWithKey:(NSString *)kMDItemAuthors ascending:YES selector:@selector(compareLastObject:)] autorelease];
	[[searchResultTableView tableColumnWithIdentifier:@"author"] setSortDescriptorPrototype:sortDescriptor];

	[[searchResultTableView tableColumnWithIdentifier:@"messagegroups"] setSortDescriptorPrototype:nil];

	[searchResultTableView setAllowsTypeSelect:NO];
	
	if (![self progressInfoVisible])
	{
		[self toggleProgressInfo:self];
	}
	
	threadMailSplitter.dividerThickness = 8.0;

	NSDictionary *options = nil;

	// Configure group view:
	messageGroupsController.refreshOutlineViewOnSetRootItem = NO;
	messageGroupsController.childKey = @"children";
	//messageGroupsController.childCountKey = @"threadChildrenCount";
	[messageGroupsController bind:@"rootItem" toObject:self withKeyPath:@"messageGroupHierarchyRootNode" options:options];
		
	// configuring manual bindings:
	threadsController.childKey = @"threadChildren";
	threadsController.childCountKey = @"threadChildrenCount";
	[threadsController bind:@"rootItem" toObject:messageGroupsController withKeyPath:@"selectedObject" options:options];
	
	[threadsController addObserver:self forKeyPath:@"selectedObjects" options:0 context:NULL];
	
	//if (threadsController) [self bind:@"selectedThreads" toObject:threadsController withKeyPath:@"selectedObjects" options:options];
		
	// configuring search results array controller:
	[self bind:@"selectedSearchResults" toObject:searchResultsArrayController withKeyPath:@"selectedObjects" options:options];
	[searchResultTableView setDoubleAction:@selector(threadsDoubleAction:)];

	// configuring comment tree view binding:
	[commentTreeView bind:@"selectedMessageOrThread" toObject:self withKeyPath:@"selectedMessageOrThread" options:options];
	[commentTreeView setTarget:self];
	[commentTreeView setAction:@selector(commentTreeSelectionChanged:)];
	
	// Configure thread view:
	[(id)threadsController.outlineView setHighlightThreads:YES];
	[threadsController.outlineView setDoubleAction:@selector(threadsDoubleAction:)];
	[threadsController.outlineView setTarget:self];
	if ([self isShowingMessageOnly])
	{
		[self setThreadsOnlyMode];
	}
	
	[groupsOutlineView setDoubleAction:@selector(groupsDoubleAction:)];
	
//	[messageTextView setEditable:NO];
//	NSAssert(![messageTextView isEditable], @"should be non editable");
		
	//	deferred enabling of autosave (timing problems otherwise):
	[threadsController.outlineView setAutosaveName:@"ThreadsAutosave"];
	[threadsController.outlineView setAutosaveTableColumns:YES];
	
	[verticalSplitter setAutosaveName:@"VerticalSplitterAutosave"];
	[threadMailSplitter setAutosaveName:@"ThreadMailSplitterAutosave"];
	[mailTreeSplitter setAutosaveName:@"MailTreeSplitterAutosave"];
	
	[groupsOutlineView setAutosaveExpandedItems:YES];
	
	// Restore group selection:
	
	NSString *urlString = [[NSUserDefaults standardUserDefaults] stringForKey:@"SelectedGroupURL"];
	GIHierarchyNode *node = [[OPPersistentObjectContext defaultContext] objectWithURLString:urlString];
	
	NSLog(@"restoring group selection %@", node);
	if (node) 
	{
		NSMutableArray *itemPath = [NSMutableArray arrayWithObject:node];
		while (node = node.parentNode) 
		{
			[itemPath insertObject: node atIndex: 0];
		}
		
		[itemPath removeObjectAtIndex:0]; // remove root node as the controller does not know anything about it. Different semantics - should this be changed?
		NSArray *itemPaths = [NSArray arrayWithObject:itemPath];
		[self.messageGroupsController setSelectedItemsPaths:itemPaths byExtendingSelection:NO];
	}	
		
	[self.window makeKeyAndOrderFront:self];
}

- (BOOL)textViewIsEditable
{
	return NO;
}

- (void)setThreadsOnlyMode
{
//	id subview = [self isSearchMode] == YES ? (id)searchResultView : (id)regularThreadsView;
	
	if (! self.isShowingThreadsOnly) {
		NSLog(@"only mail visible. switching to only threads visible.");
		[threadMailSplitter setPosition:[threadMailSplitter frame].size.height ofDividerAtIndex:0];
		[threadMailSplitter adjustSubviews];
		[self.window makeFirstResponder:[self isSearchMode] ? searchResultTableView : threadsController.outlineView];
	}
}

- (BOOL)isShowingThreadsOnly
{
	return [threadMailSplitter isSubviewCollapsed:mailTreeSplitter];
}

- (BOOL)isShowingMessageOnly
{
	NSView *upperview = [[threadMailSplitter subviews] objectAtIndex:0];
	BOOL result = [threadMailSplitter isSubviewCollapsed:upperview];
	return result;
}

- (void) adjustMailTreeSplitter
{
	CGFloat currentTreeViewHeight = [commentTreeView.superview frame].size.height;
	if (self.selectedMessage.thread.messages.count < 2) {
		// Collapse the graphical thread view, if it's too boring:
		if (currentTreeViewHeight > 0.1) {
			treeViewHeight = currentTreeViewHeight;
			[mailTreeSplitter setPosition:0.0 ofDividerAtIndex:0];
			[mailTreeSplitter adjustSubviews];
		}
	} else {
		// Uncollapse the graphical thread view, if it's useful:
		if (currentTreeViewHeight <= 0.1) {
			[mailTreeSplitter setPosition: treeViewHeight ofDividerAtIndex: 0];
			[mailTreeSplitter adjustSubviews];
		}
	}	
}

- (void)showMessageOnly
{
	// show message view and graphical thread view:
	[threadMailSplitter setPosition:0.0 ofDividerAtIndex:0];
	[threadMailSplitter adjustSubviews];

	[self adjustMailTreeSplitter];
	
	[self performSetSeenBehaviorForMessage:self.selectedMessage];
	[self.window makeFirstResponder: messageTextView];
}

- (void)performSetSeenBehaviorForMessage:(GIMessage *)aMessage
{
	static GIMessage *delayedMessage = nil;
	static NSNumber *yesNumber = nil;
	
	if (!yesNumber)
	{
		yesNumber = [[NSNumber alloc] initWithBool:YES];
	}
	
	if (delayedMessage)
	{
		[NSObject cancelPreviousPerformRequestsWithTarget:delayedMessage selector:@selector(setIsSeen:) object:yesNumber];
		
		delayedMessage = nil;
	}
	
	if (!aMessage) return;
	
	int setSeenBehavior = [[NSUserDefaults standardUserDefaults] integerForKey:SetSeenBehavior];
	
	switch(setSeenBehavior)
	{
		case GISetSeenBehaviorImmediately:
		{
			if (![aMessage hasFlags:OPSeenStatus])
			{
				[aMessage setIsSeen:YES];
			}
			break;
		}
		case GISetSeenBehaviorAfterTimeinterval:
		{
			if ([aMessage hasFlags:OPSeenStatus])
			{
				[aMessage performSelector:@selector(setIsSeen:) withObject:yesNumber afterDelay:[[NSUserDefaults standardUserDefaults] floatForKey:SetSeenTimeinterval]];
				
				delayedMessage = aMessage;
			}
		}
		default:
			break;
	}	
}

- (void) expandDetailView
{
	//if (! [[NSUserDefaults sharedUserDefaults] boolForKey: @"HideRightPaneInBackground"]) return;
	
	CGFloat dividerPos = [verticalSplitter positionOfDividerAtIndex: 0];
	
	if (expansionWidth && dividerPos >= [verticalSplitter maxPossiblePositionOfDividerAtIndex: 0]) {
		
		// expanding right pane
		NSLog(@"Expanding right pane...");
		NSRect newWindowFrame = [verticalSplitter.window frame];
		newWindowFrame.size.width += expansionWidth;
		[verticalSplitter.window setFrame: newWindowFrame display: NO animate: NO];
		//[verticalSplitter adjustSubviews];
		
		[verticalSplitter setPosition: dividerPos ofDividerAtIndex: 0];
		
	}
}

- (void) collapseDetailView
{
	if (! [[NSUserDefaults standardUserDefaults] boolForKey: @"HideRightPaneInBackground"]) return;
	
	CGFloat dividerPos = [verticalSplitter positionOfDividerAtIndex: 0];
	
	if (dividerPos < [verticalSplitter maxPossiblePositionOfDividerAtIndex: 0]) {
		
		// collapse subview
		NSLog(@"Collapsing right pane...");
		[verticalSplitter setPosition: [verticalSplitter maxPossiblePositionOfDividerAtIndex: 0] ofDividerAtIndex: 0];
		[verticalSplitter adjustSubviews];
		CGFloat newDividerPos = [verticalSplitter positionOfDividerAtIndex: 0];
		NSRect newWindowFrame = [verticalSplitter.window frame];
		expansionWidth = newDividerPos - dividerPos;
		
		newWindowFrame.size.width -= expansionWidth;
		[verticalSplitter.window setFrame: newWindowFrame display: NO animate: NO];
	}
}

- (void)showMessage:(GIMessage *)message
/*" Tries to show the message given. Selects any group the thread is in. "*/
{	
	id selectedHierarchyObject = [self.messageGroupsController selectedObject];
	NSSet *messageGroups = message.thread.messageGroups;
	
	GIMessageGroup *group = nil;
	
	// prefer selected message group:
	if ([messageGroups containsObject:selectedHierarchyObject])
	{
		group = (GIMessageGroup *)selectedHierarchyObject;
	}
	else
	{
		group = [messageGroups anyObject];
	}
	
	if (group) 
	{
		// select group:
		[messageGroupsController setSelectedItemsPaths:[NSArray arrayWithObject: [NSArray arrayWithObject:group]] byExtendingSelection:NO];
		// expand thread, if necessary:
		NSArray *itemPath =  (message.thread.messageCount > 1) ? [NSArray arrayWithObjects:message.thread, message, nil] : [NSArray arrayWithObjects:message.thread, nil];

		[threadsController setSelectedItemsPaths:[NSArray arrayWithObject:itemPath] byExtendingSelection:NO];
		
		[threadsController scrollSelectionToVisible];
	}
	
	[self adjustMailTreeSplitter];
	
	if (![self isShowingMessageOnly]) {
		[threadsController.outlineView.window makeFirstResponder:threadsController.outlineView];	
	}
}

- (BOOL)validateUserInterfaceItem:(id < NSValidatedUserInterfaceItem >)anItem
{
	SEL action = [anItem action];
	//NSLog(@"Validating %@", anItem);
	if (action == @selector(delete:))
	{
		return YES; //[(GIHierarchyNode *)[messageGroupsController selectedObject] isDeletable];
	}
	else if (action == @selector(markAsRead:))
	{
		return [threadsController selectionHasUnreadMessages];
	}
	else if (action == @selector(markAsUnread:))
	{
		return [threadsController selectionHasReadMessages];
	}
	else if (action == @selector(toggleRead:) || action == @selector(applyFilters:))
	{
		return [[threadsController selectedObjects] count] != 0;
	}
	else if (action == @selector(replyAll:) || action == @selector(replySender:) || action == @selector(forward:) || action == @selector(redirect:))
	{
		return [self selectedMessage] && [threadsController selectedObjects].count == 1;
	}
	
	return YES;
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)theItem
{
	return [self validateUserInterfaceItem:theItem];
}

- (void)suspendOutlineViewUpdates
{
	[messageGroupsController suspendUpdates];
	[threadsController suspendUpdates];
}

- (void)resumeOutlineViewUpdates
{
	[messageGroupsController resumeUpdates];
	[threadsController resumeUpdates];
}

@end

@implementation GIMainWindowController (GeneralBindings)

- (NSArray *)messageGroupHierarchyRootNodes
{
	return [[GIHierarchyNode messageGroupHierarchyRootNode] children];
}

- (NSArray *)messageGroupHierarchyRootNode
{
	return [GIHierarchyNode messageGroupHierarchyRootNode];
}

- (NSFont *)messageGroupListFont
{
	return [NSFont systemFontOfSize:12.0];
}

- (float)messageGroupListRowHeight
{
	return 18.0;
}

- (NSFont *)threadListFont
{
	return [NSFont systemFontOfSize:12.0];
}

- (float)threadListRowHeight
{
	return 16.0;
}

- (BOOL)isEditable
{
	return NO;
}

@end

#import "NSString+MessageUtils.h"

@implementation GIMainWindowController (TextViewDelegate)

- (void)textView:(NSTextView *)textView doubleClickedOnCell:(id <NSTextAttachmentCell>)cell inRect:(NSRect)cellFrame atIndex:(unsigned)charIndex
{
    NSTextAttachment *attachment;
    NSFileWrapper *fileWrapper;
    NSString *filename;
    NSRange range;
    
    attachment = [cell attachment];
    fileWrapper = [attachment fileWrapper];
    filename = [[textView textStorage] attribute:OPAttachmentPathAttribute atIndex:charIndex effectiveRange:&range];
    
    if (NSDebugEnabled) NSLog(@"double click on attachment with name %@", filename);
    
    [[NSWorkspace sharedWorkspace] openFile: filename];
}

- (void)textView:(NSTextView *)view draggedCell:(id <NSTextAttachmentCell>)cell inRect:(NSRect)rect event:(NSEvent *)event atIndex:(unsigned)charIndex
{
    NSTextAttachment *attachment;
    NSFileWrapper *fileWrapper;
    NSString *filename;
    NSRange range;
    
    attachment = [cell attachment];
    fileWrapper = [attachment fileWrapper];
    filename = [[view textStorage] attribute:OPAttachmentPathAttribute atIndex:charIndex effectiveRange:&range];
    
    if (NSDebugEnabled) NSLog(@"draggedCell %@", filename);
    
	// HTML may not contain attachment files, how do we handle D&D?
	if (filename) 
	{
		NSPoint mouseLocation = [event locationInWindow];
		
		mouseLocation.x -= 16; // file icons are guaranteed to have 32 by 32 pixels (Mac OS 10.4 NSWorkspace docs)
		mouseLocation.y -= 16;
		
		mouseLocation = [view convertPoint:mouseLocation fromView:nil];
		
		rect = NSMakeRect(mouseLocation.x, mouseLocation.y, 1, 1);
		[view dragFile:filename fromRect:rect slideBack: YES event:event];
	}
}

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)flag
{
    return NSDragOperationCopy;
}

- (BOOL)ignoreModifierKeysWhileDragging
{
    return YES;
}

/*
- (void)textView:(NSTextView *)textView spaceKeyPressedWithModifierFlags:(int)modifierFlags
{
    GIMessage *result = nil;
    GIMessage *candidate;
    
    NSArray *orderedMessages = [[self displayedThread] messagesByTree];
    int orderedMessageCount = [orderedMessages count];
    int iStart = [orderedMessages indexOfObject: [self displayedMessage]];
    int i = (iStart+1) % orderedMessageCount;
    while (i!=iStart) {
        if (([candidate = [orderedMessages objectAtIndex: i] flags] & OPSeenStatus) == 0) {
            result = candidate; break;
        }
        i = (i+1) % orderedMessageCount;
    } 
    if (result) {
        [self setDisplayedMessage: result thread: [self displayedThread]];
    } else NSBeep();
    return;
}
*/
@end

@implementation GIMainWindowController (SplitViewDelegate)

- (CGFloat)splitView:(id)sender constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset
{
	if (sender == threadMailSplitter)
	{
		CGFloat result = [sender frame].size.height - 125.0;
		return result;
	}
	return proposedMax;
}

- (CGFloat)splitView:(id)sender constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset
{
	if (sender == threadMailSplitter) {
		return 32.0;
	} else if (sender == verticalSplitter) {
		return offset == 0 ? 120.0 : 320.0;
	}
	return proposedMin;
}

- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview
{
	if (sender == threadMailSplitter)
	{
		return YES;
	}
	return NO;
}

static BOOL isShowingThreadsOnly = NO;

- (void)splitViewDidResizeSubviews:(NSNotification *)aNotification
{
	if ([aNotification object] == threadMailSplitter)
	{
		if (![self isShowingThreadsOnly] && isShowingThreadsOnly)
		{
			// The message view became visible, so make sure it is uptodate:
			[self willChangeValueForKey:@"messageForDisplay"];
			[self didChangeValueForKey:@"messageForDisplay"];
			[self performSetSeenBehaviorForMessage:self.selectedMessage];
		}
		
		// Make sure selection is visible:
		if ([self isSearchMode])
		{
			NSUInteger index = [[searchResultsArrayController selectionIndexes] lastIndex];
			if (index != NSNotFound)
			{
				[searchResultTableView scrollRowToVisible:index];
			}
		}
		else
		{
			NSUInteger index = [[threadsController.outlineView selectedRowIndexes] lastIndex];
			if (index != NSNotFound)
			{
				[threadsController.outlineView scrollRowToVisible:index];
			}
		}
	}
}

- (void)splitViewWillResizeSubviews:(NSNotification *)aNotification
{
	if ([aNotification object] == threadMailSplitter)
	{
		isShowingThreadsOnly = [self isShowingThreadsOnly];
	}
}

@end

@implementation GIMainWindowController (OutlineViewActions)

- (IBAction) groupsDoubleAction: (id) sender
{
	if ([self isShowingMessageOnly]) {
		[self setThreadsOnlyMode];
	}
}

- (IBAction)threadsDoubleAction:(id)sender
{
	GIMessage *selectedMessage = [self selectedMessage];
	unsigned messageSendStatus = [selectedMessage sendStatus];
	
	if (messageSendStatus > OPSendStatusNone) 
	{
		if (messageSendStatus >= OPSendStatusSending) 
		{
			NSLog(@"message %@ is in send job", [self selectedMessage]); // replace by alert
			NSBeep();
		} 
		else 
		{
			[[[GIMessageEditorController alloc] initWithMessage:[self selectedMessage]] autorelease];
		}
	} 
	else if (selectedMessage && self.isShowingThreadsOnly)
	{
		[self showMessageOnly];
	}
	else if (!selectedMessage)
	{
		NSArray *threads = [self selectedThreads];
		NSOutlineView* outlineView = [threadsController outlineView];
		if (threads.count == 1) {
			GIThread* selectedThread = [threads lastObject];
			if ([outlineView isItemExpanded:selectedThread]) {
				[outlineView collapseItem:selectedThread];
			} else {
				GIMessage* message = [selectedThread nextMessageForMessage: nil];
				[threadsController setSelectedItemsPaths: [NSArray arrayWithObject: [NSArray arrayWithObjects: selectedThread, message, nil]] byExtendingSelection: NO];
			}
		}
	}
}

@end

@implementation GIMainWindowController (BindingStuff)
// -- binding stuff --

+ (void)initialize
{
    [self exposeBinding:@"selectedSearchResults"];
}

- (Class)valueClassForBinding:(NSString *)binding
{
	return [NSArray class];
}

- (id)observedObjectForSelectedSearchResults { return observedObjectForSelectedSearchResults; }
- (void)setObservedObjectForSelectedSearchResults:(id)anObservedObjectForSelectedSearchResults
{
    if (observedObjectForSelectedSearchResults != anObservedObjectForSelectedSearchResults) 
	{
        [observedObjectForSelectedSearchResults release];
        observedObjectForSelectedSearchResults = [anObservedObjectForSelectedSearchResults retain];
    }
}

- (NSString *)observedKeyPathForSelectedSearchResults { return observedKeyPathForSelectedSearchResults; }
- (void)setObservedKeyPathForSelectedSearchResults:(NSString *)anObservedKeyPathForSelectedSearchResults
{
    if (observedKeyPathForSelectedSearchResults != anObservedKeyPathForSelectedSearchResults) 
	{
        [observedKeyPathForSelectedSearchResults release];
        observedKeyPathForSelectedSearchResults = [anObservedKeyPathForSelectedSearchResults copy];
    }
}

- (void)bind:(NSString *)bindingName
    toObject:(id)observableController
 withKeyPath:(NSString *)keyPath
     options:(NSDictionary *)options
{	
	if ([bindingName isEqualToString:@"selectedSearchResults"])
    {
		// observe the controller for changes
		[observableController addObserver:self
							   forKeyPath:keyPath 
								  options:0
								  context:nil];
		
		// register what controller and what keypath are 
		// associated with this binding
		[self setObservedObjectForSelectedSearchResults:observableController];
		[self setObservedKeyPathForSelectedSearchResults:keyPath];	
    }
	
	[super bind:bindingName
	   toObject:observableController
	withKeyPath:keyPath
		options:options];
}

- (void)unbind:bindingName
{
	if ([bindingName isEqualToString:@"selectedSearchResults"])
    {
		[observedObjectForSelectedSearchResults removeObserver:self
											  forKeyPath:observedKeyPathForSelectedSearchResults];
		[self setObservedObjectForSelectedSearchResults:nil];
		[self setObservedKeyPathForSelectedSearchResults:nil];
    }	
		
	[super unbind:bindingName];
}

- (void)observeValueForKeyPath:(NSString *)keyPath 
					  ofObject:(id)object 
						change:(NSDictionary *)change 
					   context:(void *)context
{
	if (object == threadsController && [keyPath isEqualToString:@"selectedObjects"])
	{ 
		//NSLog(@"observation info: %@", [self observationInfo]);
		
		self.selectedThreads = threadsController.selectedObjects;
		
		[[messageWebView mainFrame] loadArchive:[self webArchiveForDisplay]];
				
		if (!self.isShowingThreadsOnly)
		{
			GIMessage *selectedMessage = self.selectedMessage;		
			[self performSetSeenBehaviorForMessage:selectedMessage];
		}		
	}
	else if (object == searchResultsArrayController && [keyPath isEqualToString:[self observedKeyPathForSelectedSearchResults]])
	{ 
		// search hits changed
		id newSelectedSearchResults = [observedObjectForSelectedSearchResults valueForKeyPath:observedKeyPathForSelectedSearchResults];
		[self setSelectedSearchResults:newSelectedSearchResults];
		
		if (! self.isShowingThreadsOnly) {
			GIMessage *selectedMessage = self.selectedMessage;		
			[self performSetSeenBehaviorForMessage:selectedMessage];
		}
	}
	else
	{
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}


@end

@implementation GIMainWindowController (KeyboardShortcuts)

/*" Returns YES if the message view was scrolled down. NO otherwise. "*/
- (BOOL)scrollMessageTextViewPageDown
{
	NSPoint currentScrollPosition = [[messageTextScrollView contentView] bounds].origin;
	
	if (currentScrollPosition.y == (NSMaxY([[messageTextScrollView documentView] frame]) 
									- NSHeight([[messageTextScrollView contentView] bounds]))) return NO;
	
	// scroll page down:
	NSClipView *clipView = [messageTextScrollView documentView];
	[clipView scrollPageDown:self];
	
	
//	float height = NSHeight([[messageTextScrollView contentView] bounds]);
//	currentScrollPosition.y += height;
//	if (height > (16 * 2)) // overlapping
//	{
//		currentScrollPosition.y -= 16;
//	}
//	
//	if (currentScrollPosition.y > (NSMaxY([[messageTextScrollView documentView] frame]) 
//								   - NSHeight([[messageTextScrollView contentView] bounds]))) 
//	{
//		currentScrollPosition.y = (NSMaxY([[messageTextScrollView documentView] frame]) 
//								   - NSHeight([[messageTextScrollView contentView] bounds]));
//	}
//	
//	[[messageTextScrollView documentView] scrollPoint:currentScrollPosition];
	
	return YES;
}

/*" Returns the next message appropriate for viewing (in this case the next unread which might be eventually change/be user customizable). Or nil if no such message can be found. "*/
- (GIMessage *)nextMessage
{
	id selectedMessageOrThread = [self selectedMessageOrThread];
	GIThread *thread = nil;
	GIMessage *message = nil;
	
	if ([selectedMessageOrThread isKindOfClass:[GIMessage class]])
	{
		message = selectedMessageOrThread;
		thread = message.thread;
	}
	else
	{
		thread = selectedMessageOrThread;
	}
	
	GIMessage *result = [thread nextMessageForMessage:message];
	
	if (result.isSeen) result = nil;
	
	while (thread != nil && result == nil)
	{
		// look for next thread:
		NSArray *threadsArray = [(OPLargePersistentSet *)self.selectedGroup.threads sortedArray];
		NSUInteger index = [threadsArray indexOfObjectIdenticalTo:thread];
		
		index += 1;
		
		if (index < threadsArray.count)
		{
			thread = [threadsArray objectAtIndex:index];
		}
		else
		{
			thread = nil;
		}
		
		result = [thread nextMessageForMessage:nil];
		if (result.isSeen) result = nil;
	}
	
	return result;	
}

- (IBAction)goAhead:(id)sender
{
	// scroll message text view down if possible...
	// ...go to "next" message otherwise:
	if (![self scrollMessageTextViewPageDown])
	{
		GIMessage *nextMessage = [self nextMessage];
		
		if (nextMessage)
		{
			[self showMessage:nextMessage];
		}
		else
		{
			NSBeep();
		}
	}
}

- (IBAction)goNextAndMarkSeen:(id)sender
{
	[self selectedMessage].isSeen = YES;
	
	GIMessage *nextMessage = [self nextMessage];
	
	if (nextMessage)
	{
		[self showMessage:nextMessage];
	}
	else
	{
		NSBeep();
	}
}

- (IBAction)goAheadAndMarkSeen:(id)sender
{
	// scroll message text view down if possible...
	// ...mark as seen and go to "next" message otherwise:
	if (![self scrollMessageTextViewPageDown])
	{
		[self goNextAndMarkSeen:sender];
	}
}

#define LEFT_A 0
#define DOWN_S 1
#define RIGHT_D 2
#define UP_W 13
#define ESC 53
#define BACKSPACE 51
#define RETURN 36
#define SPACE 49
#define N_KEY 45
#define B_KEY 11
#define R_KEY 15
#define LEFT_KEYPAD_4 86
#define RIGHT_KEYPAD_6 88
#define UP_KEYPAD_8 91
#define DOWN_KEYPAD_5 87
#define DOWN_KEYPAD_2 84



- (BOOL)keyPressed:(NSEvent *)event
{
//	if ([event modifierFlags] & NSDeviceIndependentModifierFlagsMask) return NO;
	
	int keyCode = event.keyCode;
	switch(keyCode)
	{
		case LEFT_A:
		case LEFT_KEYPAD_4:
			[commentTreeView navigateLeftInMatrix:self];
			return YES;
		case DOWN_S:
		case DOWN_KEYPAD_2:
		case DOWN_KEYPAD_5:
			[commentTreeView navigateDownInMatrix:self];
			return YES;
		case RIGHT_D:
		case RIGHT_KEYPAD_6:
			[commentTreeView navigateRightInMatrix:self];
			return YES;
		case UP_W:
		case UP_KEYPAD_8:
			[commentTreeView navigateUpInMatrix:self];
			return YES;
		case ESC:
		case BACKSPACE:
		{
			[self navigateBack: self];
			return YES;
		}
		case RETURN:
		{
			if ([self.window firstResponder] == threadsController.outlineView)
			{
				[self threadsDoubleAction:threadsController.outlineView];
				return YES;
			}
			else if ([self.window firstResponder] == searchResultTableView)
			{
				[self threadsDoubleAction:threadsController.outlineView];
				return YES;
			}
			break;
		}
		case SPACE:
		{
			if ([event modifierFlags] & NSControlKeyMask) // Control pressed
			{
				[self goAhead:self];
			}
			else
			{
				[self goAheadAndMarkSeen:self];
			}
			return YES;
		}
		case N_KEY:
			[self goNextAndMarkSeen:self];
			return YES;
		case R_KEY:
			[self toggleRead:self];
			return YES;
		default:
			break;
	}
	
	return NO;
}

@end

@implementation GIMainWindowController (StatusPane)

- (BOOL)showsStatusPane
{
// TODO: dummy for now (status/progress pane)
	return NO;
}

+ (NSSet *)keyPathsForValuesAffectingStatusPaneButtonImage
{
	return [NSSet setWithObject:@"showsStatusPane"];
}

- (NSImage *)statusPaneButtonImage
{
	return [NSImage imageNamed:[self showsStatusPane] ? @"Hide_Status" : @"Show_Status"];
}

+ (NSSet *)keyPathsForValuesAffectingStatusPaneButtonAlternateImage
{
	return [NSSet setWithObject:@"showsStatusPane"];
}

- (NSImage *)statusPaneButtonAlternateImage
{
	return [NSImage imageNamed:[self showsStatusPane] ? @"Hide_Status_Pressed" : @"Show_Status_Pressed"];
}

@end

@implementation GIMainWindowController (Actions)

- (IBAction) navigateBack: (id) sender
{
	// if only mail is visible, switch back to only thread list visible
	NSLog(@"subviews of thread mail splitter = %@", [threadMailSplitter subviews]);
	NSLog(@"[threadsOutlineView superview] = %@", [[threadsController.outlineView superview] superview]);
	
	[self setThreadsOnlyMode];
}






#pragma mark -- adding new hierarchy objects --
- (void)addNew:(Class)aClass withName:(NSString *)aName
{
	// if selection of message hierarchy is a folder, add new object in
	// this folder (at the end)
	
	id selectedObject = [messageGroupsController selectedObject];
	GIHierarchyNode *hierarchyNode = [GIHierarchyNode messageGroupHierarchyRootNode];
	
	if (![selectedObject isKindOfClass:[GIMessageGroup class]])
	{
		hierarchyNode = selectedObject;
	}
	
	[messageGroupsController.outlineView expandItem:hierarchyNode];
	
	NSUInteger position = [[hierarchyNode children] count];
	
	id newObject = [aClass newWithName:aName atHierarchyNode:hierarchyNode atIndex:position];
	
	[messageGroupsController setSelectedItemsPaths:[NSArray arrayWithObject:[messageGroupsController itemPathForItem:newObject]] byExtendingSelection:NO];
	
	[messageGroupsController.outlineView scrollRowToVisible:[messageGroupsController.outlineView rowForItem:newObject]];
	
	[self performSelector:@selector(rename:) withObject:self afterDelay:0.0];
}

- (IBAction)addNewMessageGroup:(id)sender
{
	[self addNew:[GIMessageGroup class] withName:@"New Box"];
}

- (IBAction)addNewFolder:(id)sender
{
	[self addNew:[GIHierarchyNode class] withName:@"New Folder"];
}

#pragma mark -- deletion of hierarchy objects  --
- (IBAction)delete:(id)sender
{
	if ([[messageTextView window] firstResponder] == (NSResponder *)messageTextView) 
	{
		[(id)threadsController.outlineView delete:sender];
		if ([self isShowingMessageOnly]) 
		{
			[self setThreadsOnlyMode];
		}
		return;
	}
	
	GIHierarchyNode *node = messageGroupsController.selectedObject;
	
	NSString *nodeType = [node isKindOfClass:[GIMessageGroup class]] ? NSLocalizedString(@"Mailbox", @"Delete warning dialog") : NSLocalizedString(@"Folder", @"Delete warning dialog");
	NSAlert *alert = [[NSAlert alloc] init];
	
	[alert addButtonWithTitle:NSLocalizedString(@"Delete", @"Delete warning dialog")];
	[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Delete warning dialog")];
	[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Delete %@ '%@' and all of its contents?", @"Delete warning dialog"), nodeType, node.name]];
	[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"The deleted %@ cannot be restored.", @"Delete warning dialog"), nodeType]];
	[alert setAlertStyle:NSWarningAlertStyle];	
	
	if ([alert runModal] == NSAlertFirstButtonReturn) {
		// Delete clicked, delete the node
		@try
		{
			[self.messageGroupsController suspendUpdates];
			[threadsController suspendUpdates];
			
			[self.messageGroupsController deleteHierarchyNode:node];
		}
		@finally
		{
			[self.messageGroupsController resumeUpdates];
			[threadsController resumeUpdates];
		}
	}
	
	[alert release];
}

#pragma mark -- renaming hierarchy objects --
- (IBAction)rename:(id)sender
{
	GIHierarchyNode *node = messageGroupsController.selectedObject;
	if (node)
	{
		messageGroupNameField.stringValue = node.name;
		
		[NSApp beginSheet:messageGroupRenameWindow modalForWindow:self.window modalDelegate:self didEndSelector:NULL contextInfo:NULL];
	}
}

- (IBAction)doRename:(id)sender
{
	GIHierarchyNode *node = messageGroupsController.selectedObject;
	
	node.name = messageGroupNameField.stringValue;
	
	[NSApp endSheet:messageGroupRenameWindow];
	[messageGroupRenameWindow orderOut:self];
}

- (IBAction)cancelRename:(id)sender
{
	[NSApp endSheet:messageGroupRenameWindow];
	[messageGroupRenameWindow orderOut:self];
}

#pragma mark -- message creation --
- (GIProfile *)profileForMessage:(GIMessage *)aMessage
/*" Return the profile to use for email replies. Tries first to guess a profile based on the replied email. If no matching profile can be found, the group default profile is chosen. May return nil in case of no group default and no match present. "*/
{
    GIProfile *result;
    
    result = [GIProfile guessedProfileForReplyingToMessage:[aMessage internetMessage]];
    
    if (!result)
    {
        result = [[self selectedGroup] defaultProfile];
    }
    
	if (!result)
	{
		result = [GIProfile defaultProfile];
	}
	
    return result;
}

- (void)placeSelectedTextOnQuotePasteboard
{
    NSArray *types = [messageTextView writablePasteboardTypes];
    NSPasteboard *quotePasteboard = [NSPasteboard pasteboardWithName:@"QuotePasteboard"];
    
    [quotePasteboard declareTypes:types owner:nil];
    [messageTextView writeSelectionToPasteboard:quotePasteboard types:types];
}

- (IBAction)newMessage:(id)sender
{
	GIProfile *profileForNewMessage = nil;
	
	id selectedObject = [messageGroupsController selectedObject];
	if ([selectedObject isKindOfClass:[GIMessageGroup class]])
	{
		profileForNewMessage = [selectedObject defaultProfile];
	}
	
    [[[GIMessageEditorController alloc] initNewMessageWithProfile:profileForNewMessage] autorelease];
}

- (IBAction)replyAll:(id)sender
{
    GIMessage *message = [self selectedMessage];
    
    [self placeSelectedTextOnQuotePasteboard];
    
    [[[GIMessageEditorController alloc] initReplyTo:message all:YES profile:[self profileForMessage:message]] autorelease];
}

- (IBAction)replySender:(id)sender
{
    GIMessage *message = [self selectedMessage];
    
    [self placeSelectedTextOnQuotePasteboard];
    
    [[[GIMessageEditorController alloc] initReplyTo:message all:NO profile:[self profileForMessage:message]] autorelease];
}

- (IBAction)followup:(id)sender
{
    GIMessage *message = [self selectedMessage];
    
    [self placeSelectedTextOnQuotePasteboard];
    
    [[[GIMessageEditorController alloc] initFollowupTo:message profile:[[self selectedGroup] defaultProfile]] autorelease];
}

- (IBAction)replyDefault:(id)sender
{
    GIMessage *message = [self selectedMessage];
	
    if ([message isListMessage] || [message isUsenetMessage]) 
	{
        [self followup:sender];
    } 
	else 
	{
        [self replySender:sender];
    }
}

- (IBAction)forward:(id)sender
{
    GIMessage *message = [self selectedMessage];
	
    [[[GIMessageEditorController alloc] initForward:message profile:[self profileForMessage:message]] autorelease];
}

- (IBAction)redirect:(id)sender
{
	self.redirectProfile = [self profileForMessage:self.selectedMessage];
	
	// show sheet:	
	[NSApp beginSheet:redirectSheet modalForWindow:self.window modalDelegate:self didEndSelector:NULL contextInfo:NULL];
}

#pragma mark -- message flags manipulation --
- (IBAction)markAsRead:(id)sender
{
	for (GIMessage *message in [self selectedMessages]) 
	{
		message.isSeen = YES;
	}
}

- (IBAction)markAsUnread:(id)sender
{
	for (GIMessage *message in [self selectedMessages]) 
	{
		message.isSeen = NO;
	}
}

- (IBAction)toggleRead:(id)sender
{
	if ([self selectionHasUnreadMessages]) 
	{
		[self markAsRead:self];
	} 
	else 
	{
		[self markAsUnread:self];
	}
}

#pragma mark -- message display option handling --
- (IBAction)toggleShowRawSource:(id)sender
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setBool:![defaults boolForKey:ShowRawSource] forKey:ShowRawSource];
	
	[self willChangeValueForKey:@"messageForDisplay"];
	[self didChangeValueForKey:@"messageForDisplay"];
}

- (IBAction)toggleShowAllHeaders:(id)sender
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setBool:![defaults boolForKey:ShowAllHeaders] forKey:ShowAllHeaders];
	
	[self willChangeValueForKey:@"messageForDisplay"];
	[self didChangeValueForKey:@"messageForDisplay"];
}

#pragma mark -- progress info view handling --
- (void)setProgressInfoVisible:(BOOL)aBool
{
	[[NSUserDefaults standardUserDefaults] setBool:aBool forKey:ProgressInfoShown];
}

- (BOOL)progressInfoVisible
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:ProgressInfoShown];
}

- (IBAction)toggleProgressInfo:(id)sender
{
	NSRect frame = progressInfoScrollView.frame;
	
	if (frame.size.height != 0.0)
	{
		progressInfoHeight = progressInfoScrollView.frame.size.height;
		
		// hide progress info:
		frame.size.height = 0.0;
		progressInfoScrollView.frame = frame;
		[self setProgressInfoVisible:NO];
	}
	else
	{
	}
}


#pragma mark -- Miscellaneous --
- (IBAction)commentTreeSelectionChanged:(id)sender
{
	GIMessage *message = [commentTreeView selectedMessage];
	
	if ([self isSearchMode])
	{
		self.selectedMessageInSearchMode = message;
		[searchResultTableView deselectAll:self];
		if (message)
		{
			[self performSetSeenBehaviorForMessage:message];
		}
	}
	else	
	{
		if (message) 
		{
			[self showMessage:message];
		}
	}
}

- (IBAction)messageGroupSelectionChanged:(id)sender
{
//	NSUInteger threadCount = [messageGroupsController.selectedObject threads].count;
//	NSUInteger totalMessageCount = [messageGroupsController.selectedObject messageCount];
//	NSUInteger totalMessageCount2 = [messageGroupsController.selectedObject calculatedMessageCount];
//	NSUInteger unreadMessageCount = [messageGroupsController.selectedObject unreadMessageCount];
//	NSUInteger unreadMessageCount2 = [messageGroupsController.selectedObject calculatedUnreadMessageCount];
//	NSUInteger unreadMessageCount3 = [messageGroupsController.selectedObject calculatedUnreadMessageCount2];
//	
	
	if ([self isShowingMessageOnly])
	{
		[self setThreadsOnlyMode];
	}
	
	// if search with 'selected mailbox' is active then signal a filter change:
	if ([self isSearchMode] && [[NSUserDefaults standardUserDefaults] integerForKey:@"SearchRange"] == SEARCHRANGE_SELECTEDGROUP)
	{
		[self searchRangeChanged:sender];
	}
	else
	{
		[searchField setStringValue:@""];
		[self search:sender];
	}
}

- (IBAction)applyFilters:(id)sender
{
	NSMutableSet *result = [NSMutableSet setWithCapacity:self.selectedThreads.count];
	
	for (id selectedObject in self.selectedThreads)
	{
		if ([selectedObject isKindOfClass:[GIMessage class]])
		{
			[result addObject:[selectedObject thread]];
		}
		else
		{
			NSAssert([selectedObject isKindOfClass:[GIThread class]], @"thread expected");
			[result addObject:selectedObject];
		}
	}

	@try
	{
		[self suspendOutlineViewUpdates];
		[GIMessageFilter applyFiltersToThreads:result inGroup:messageGroupsController.selectedObject];
	}
	@finally
	{
		[self resumeOutlineViewUpdates];
	}
}

- (IBAction)debug:(id)sender
{
	//	NSLog(@"to = %@", [[[self selectedMessage] internetMessage] toWithFallback:NO]);
}

@end

@implementation GIMainWindowController (Search)

- (void)setSearchMode:(BOOL)aBool
{
	if (aBool == searchMode) return;
	
	if (aBool) {
		// switch to all mailboxes search:
		[[NSUserDefaults standardUserDefaults] setInteger:SEARCHRANGE_ALLMESSAGEGROUPS forKey:@"SearchRange"];
		
		[self willChangeValueForKey:@"searchResultFilter"];
		[self didChangeValueForKey:@"searchResultFilter"];
	}
	else
	{
		[searchField setStringValue:@""];
		self.selectedMessageInSearchMode = nil;
	}
	
	// ...otherwise switch views:
	NSView *oldView = nil;
	NSView *newView = nil;
	
	if (searchMode)
	{
		oldView = searchResultView;
		newView = regularThreadsView;
	}
	else
	{
		oldView = regularThreadsView;
		newView = searchResultView;
	}
	
	newView.frame = oldView.frame;

	BOOL isShowingMessageOnly = [self isShowingMessageOnly];
	BOOL isShowingThreadsOnly = [self isShowingThreadsOnly];
#warning Bug: Will dealloc outline view -> outlineView reference in outlineView Controller will dangle.
	NSMutableArray *subviews = [[threadMailSplitter subviews] mutableCopy];
	[subviews replaceObjectAtIndex:0 withObject:newView];
	
	[threadMailSplitter setSubviews:subviews];
	
	if (isShowingMessageOnly)
	{
		[self showMessageOnly];
	}
	else if (isShowingThreadsOnly)
	{
		[self setThreadsOnlyMode];
	}
	
	[self.window display];
	
	searchMode = aBool;
	
	if (!aBool)
	{
		[self willChangeValueForKey:@"selectedThreads"];
		[self didChangeValueForKey:@"selectedThreads"];
	}
}

- (BOOL) isSearchMode
{
	return searchMode;
}

- (NSArray *)searchSortDescriptors
{
	NSData *sortDescriptorData = [[NSUserDefaults standardUserDefaults] objectForKey:@"SearchSortDescriptors"];
	if (!sortDescriptorData) return [NSArray array];
	
	NSArray *result = [NSKeyedUnarchiver unarchiveObjectWithData:sortDescriptorData];
	
	return result;
}

- (void)setSearchSortDescriptors:(NSArray *)anArray
{
	if (!anArray) [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"SearchSortDescriptors"];
	NSData *sortDescriptorData = [NSKeyedArchiver archivedDataWithRootObject:anArray];
	[[NSUserDefaults standardUserDefaults] setObject:sortDescriptorData forKey:@"SearchSortDescriptors"];
	
	[query setSortDescriptors:anArray];
}

- (IBAction)search:(id)sender
{
	NSString *searchPhrase = [searchField stringValue];
	
	if (searchPhrase.length)
	{
		NSString *searchPhraseContains = [NSString stringWithFormat:@"*%@*", searchPhrase];
		
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		NSInteger searchFields = [defaults integerForKey:@"SearchFields"];
		
		[query setSortDescriptors:[self searchSortDescriptors]];
		
		[self setSearchMode:YES];
		
		// Switch away from message only mode, so search results are visible:
		if (self.isShowingMessageOnly) {
			[self setThreadsOnlyMode];
		}
		
		switch (searchFields)
		{
			case SEARCHFIELDS_ALL:
				[query setPredicate:[NSPredicate predicateWithFormat:@"(kMDItemContentTypeTree == 'org.objectpark.gina.message') AND ((kMDItemTextContent like[cd] %@) OR (kMDItemSubject like[cd] %@) OR (kMDItemAuthors like[cd] %@) OR (kMDItemAuthorEmailAddresses like[cd] %@) OR (kMDItemRecipients like[cd] %@) OR (kMDItemRecipientEmailAddresses like[cd] %@))", searchPhrase, searchPhraseContains, searchPhraseContains, searchPhraseContains, searchPhraseContains, searchPhraseContains]];
				break;
			case SEARCHFIELDS_AUTHOR:
				[query setPredicate:[NSPredicate predicateWithFormat:@"(kMDItemContentTypeTree == 'org.objectpark.gina.message') AND ((kMDItemAuthors like[cd] %@) OR (kMDItemAuthorEmailAddresses like[cd] %@))", searchPhraseContains, searchPhraseContains]];
				break;
			case SEARCHFIELDS_SUBJECT:
				[query setPredicate:[NSPredicate predicateWithFormat:@"(kMDItemContentTypeTree == 'org.objectpark.gina.message') AND (kMDItemSubject like[cd] %@)", searchPhraseContains]];
				break;
			case SEARCHFIELDS_RECIPIENTS:
				[query setPredicate:[NSPredicate predicateWithFormat:@"(kMDItemContentTypeTree == 'org.objectpark.gina.message') AND ((kMDItemRecipients like[cd] %@) OR (kMDItemRecipientEmailAddresses like[cd] %@))", searchPhraseContains, searchPhraseContains]];
				break;
			default:
				NSAssert(NO, @"no search fields specified");
				break;
		}
		
//		[query setSearchScopes:[NSArray arrayWithObjects:NSMetadataQueryUserHomeScope, nil]];
		
		[query startQuery];
	}
	else
	{
		[self setSearchMode:NO];
	}
}

- (NSPredicate *)searchResultFilter
{
	// check if filtering needed:
	NSInteger searchRange = [[NSUserDefaults standardUserDefaults] integerForKey:@"SearchRange"];
	
	GIMessageGroup *selectedGroup = self.messageGroupsController.selectedObject;
	
	if ([selectedGroup isKindOfClass:[GIMessageGroup class]])
	{
		if (searchRange == SEARCHRANGE_SELECTEDGROUP)
		{
			//			NSLog(@"selected group");
			NSPredicate *result = [NSPredicate predicateWithFormat:@"%@ in message.thread.messageGroups", selectedGroup]; 
			return result;
		}
		//		else
		//		{
		//			NSLog(@"all groups");
		//		}
	}
	
	return nil;
}

- (IBAction)searchRangeChanged:(id)sender
{
	[self willChangeValueForKey:@"searchResultFilter"];
	[self didChangeValueForKey:@"searchResultFilter"];
	[self.searchResultTableView willChangeValueForKey:@"numberOfRows"];
	[self.searchResultTableView didChangeValueForKey:@"numberOfRows"];
}

- (void)queryNotification:(NSNotification *)note
{
    // the NSMetadataQuery will send back a note when updates are happening.
	
    // by looking at the [note name], we can tell what is happening
    if ([[note name] isEqualToString:NSMetadataQueryDidStartGatheringNotification])
    {
        // the query has just started
        NSLog(@"search: started gathering");
    }
    else if ([[note name] isEqualToString:NSMetadataQueryDidFinishGatheringNotification])
    {
        // at this point, the query will be done. You may recieve an update later on.
        NSLog(@"search: finished gathering");
		[self.searchResultTableView willChangeValueForKey:@"numberOfRows"];
		[self.searchResultTableView didChangeValueForKey:@"numberOfRows"];
		//        [self processSearchResult:[note object]];
    }
    else if ([[note name] isEqualToString:NSMetadataQueryGatheringProgressNotification])
    {
        // the query is still gatherint results...
        NSLog(@"search: progressing...");
    }
    else if ([[note name] isEqualToString:NSMetadataQueryDidUpdateNotification])
    {
        // an update will happen when Spotlight notices that a file as added,
        // removed, or modified that affected the search results.
        NSLog(@"search: an update happened.");
    }
}

@end

#import "EDDateFieldCoder.h"
#import "GIMailAddressTokenFieldDelegate.h"

@implementation GIMainWindowController (MessageRedirect)

- (NSArray *)allProfiles
{
	return [[[OPPersistentObjectContext defaultContext] allObjectsOfClass:[GIProfile class]] allObjects];
}

- (NSArray *)profileSortDescriptors
{
	static NSArray *sortDescriptors = nil;
	
	if (! sortDescriptors) 
	{
		sortDescriptors = [[NSArray alloc] initWithObjects:[[[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES] autorelease], nil];
	}
	
	return sortDescriptors;
}

- (IBAction)doRedirect:(id)sender
{
	[redirectSheet endEditingFor:[redirectSheet firstResponder]];
	[NSApp endSheet:redirectSheet];
    [redirectSheet orderOut:sender];
	
	// copy selected message:
	GIMessage *selectedMessage = self.selectedMessage;
	OPInternetMessage *selectedInternetMessage = selectedMessage.internetMessage;
		
	OPInternetMessage *resentInternetMessage = [[OPInternetMessage alloc] initWithTransferData:selectedInternetMessage.transferData];
	
	// set additional informal resent header fields:
	NSString *resentMessageId = [resentInternetMessage generatedMessageIdWithSuffix:[NSString stringWithFormat:@"@%@", redirectProfile.sendAccount.outgoingServerName]];
	
	[resentInternetMessage addToHeaderFieldsName:@"Resent-Message-ID" body:resentMessageId];
	
	EDDateFieldCoder *fCoder;
    NSCalendarDate *date = [NSCalendarDate date];
    fCoder = [[EDDateFieldCoder alloc] initWithDate:date];
	[resentInternetMessage addToHeaderFieldsName:@"Resent-Date" body:[fCoder fieldBody]];
    [fCoder release];
	
	NSString *fromString = [redirectProfile fromString];
	[resentInternetMessage addToHeaderFieldsName:@"Resent-From" body:fromString];
	
	NSString *bccString = self.resentBcc.count ? [self.resentBcc componentsJoinedByString:@", "] : nil;
	[resentInternetMessage addToHeaderFieldsName:@"Resent-Bcc" body:bccString];
	
	NSString *ccString = self.resentCc.count ? [self.resentCc componentsJoinedByString:@", "] : nil;
	[resentInternetMessage addToHeaderFieldsName:@"Resent-Cc" body:ccString];
	
	NSString *toString = self.resentTo.count ? [self.resentTo componentsJoinedByString:@", "] : nil;
	[resentInternetMessage addToHeaderFieldsName:@"Resent-To" body:toString];
	
	// construct resent message:
	GIMessage *resentMessage = [[[GIMessage alloc] initWithInternetMessage:resentInternetMessage appendToAppropriateThread:NO forcedMessageId:resentMessageId] autorelease];
		
	// mark message as resent:
	if (![resentMessage hasFlags:OPResentStatus])
	{
		[resentMessage toggleFlags:OPResentStatus];
	}
	
	// mark message as to send:
	[resentMessage setSendStatus:OPSendStatusQueuedReady];
	
//	NSLog(@"resentMessage = %@", resentMessage);
	
	// queue message:
	GIThread *thread = resentMessage.thread;
	NSMutableSet *messageGroups = [thread mutableSetValueForKey:@"messageGroups"];
	
	//add new message to queued message group:
	[messageGroups addObject:[GIMessageGroup queuedMessageGroup]];
	
	// Set message in profile's messagesToSend:
	[[redirectProfile mutableArrayValueForKey:@"messagesToSend"] addObject:resentMessage];	
	[redirectProfile.sendAccount send];
	
	// housekeeping LRU address cache:
	[GIMailAddressTokenFieldDelegate addToLRUMailAddresses:toString];
	[GIMailAddressTokenFieldDelegate addToLRUMailAddresses:ccString];
	[GIMailAddressTokenFieldDelegate addToLRUMailAddresses:bccString];
}

- (IBAction)cancelRedirect:(id)sender
{
	[NSApp endSheet:redirectSheet];
    [redirectSheet orderOut:sender];
}

@end

@implementation NSArray (GIComparing)

- (NSComparisonResult)compareLastObject:(id)otherArray
{
	id thisLastObject = [self lastObject];
	id otherLastObject = [otherArray lastObject];
	
	return [thisLastObject compare:otherLastObject];
}

@end

