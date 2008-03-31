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
#import "KFSplitView.h"

#import "GIUserDefaultsKeys.h"

// helper
#import <Foundation/NSDebug.h>
#import "NSArray+Extensions.h"
#import "NSAttributedString+Extensions.h"
#import "NSString+Extensions.h"

// model stuff
#import "OPPersistentObject.h"

#import "GIThread.h"
#import "GIMessage.h"
#import "GIMessage+Rendering.h"
#import "GIHierarchyNode.h"
#import "GIMessageGroup.h"

@implementation GIMessageGroup (copying)
- (id)copyWithZone:(NSZone *)aZone
{
	return [self retain];
}
@end

@implementation GIMainWindowController

@synthesize selectedThreads;
@synthesize messageGroupsController;

+ (NSSet *)keyPathsForValuesAffectingSelectedMessageOrThread
{
	return [NSSet setWithObject:@"selectedThreads"];
}

- (id)selectedMessageOrThread
{
	NSArray *threads = self.selectedThreads;
	if ([threads count] == 1)
	{
		return [threads lastObject];
	}
	
	return nil;	
}

+ (NSSet *)keyPathsForValuesAffectingMessageForDisplay
{
	return [NSSet setWithObject:@"selectedMessageOrThread"];
}

- (NSAttributedString *)messageForDisplay
{
	id selectedObject = self.selectedMessageOrThread;
	
	if (!selectedObject) return [[[NSAttributedString alloc] init] autorelease];
	
	NSAttributedString *result = [selectedObject messageForDisplay];
	//NSLog(@"message for display: %@", [result string]);
	
	return result;
}

- (GIMessageGroup *)selectedGroup
{
	id result = [messageGroupsController selectedObject];
	if (![result isKindOfClass:[GIMessageGroup class]]) result = nil;
	return result;
}

+ (NSSet *)keyPathsForValuesAffectingSelectedMessage
{
	return [NSSet setWithObject:@"selectedThreads"];
}

- (GIMessage *)selectedMessage
{
	GIMessage *result = nil;
	
	if ([[self selectedThreads] count] == 1)
	{
		result = [(GIThread *)[[self selectedThreads] lastObject] message];
	}
	
	return result;
}

- (id)init
{
	self = [self initWithWindowNibName:@"MainWindow"];
		
	[self retain];
	
	[self showWindow:self];

	return self;
}

- (void)dealloc
{
	NSLog(@"GIMainWindowController dealloc");
 	[super dealloc];
}

- (void)windowWillClose:(NSNotification *)notification
{
	[self unbind:@"selectedThreads"];
	[threadsController unbind:@"rootItem"];
	[commentTreeView unbind:@"selectedMessageOrThread"];
	
	[self autorelease];
}

- (IBAction)groupTreeSelectionChanged:(id)sender
{
	[self setThreadsOnlyMode];
}

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

- (void)awakeFromNib
{
}

- (void)windowDidLoad
{
	if (![self progressInfoVisible])
	{
		[self toggleProgressInfo:self];
	}
	
	threadMailSplitter.dividerThickness = 8.0;
	[threadMailSplitter setPositionAutosaveName:@"KFThreadMailSplitter"];
	[verticalSplitter setPositionAutosaveName:@"KFVerticalSplitter"];
	[mailTreeSplitter setPositionAutosaveName:@"KFMailTreeSplitter"];

	// configuring manual bindings:
	NSDictionary *options = nil;
	
	threadsController.childKey = @"threadChildren";
	threadsController.childCountKey = @"threadChildrenCount";
	[threadsController bind:@"rootItem" toObject:messageGroupsController withKeyPath:@"selectedObject" options:options];
	
	if (threadsController) [self bind:@"selectedThreads" toObject:threadsController withKeyPath:@"selectedObjects" options:options];
		
	// configuring comment tree view binding:
	[commentTreeView bind:@"selectedMessageOrThread" toObject:self withKeyPath:@"selectedMessageOrThread" options:options];
	[commentTreeView setTarget:self];
	[commentTreeView setAction:@selector(commentTreeSelectionChanged:)];
	
	// Configure thread view:
	[threadsOutlineView setHighlightThreads:YES];
	[threadsOutlineView setDoubleAction:@selector(threadsDoubleAction:)];
	[threadsOutlineView setTarget:self];
	[self setThreadsOnlyMode];
	
	// Configure group view:
	messageGroupsController.childKey = @"children";
	//messageGroupsController.childCountKey = @"threadChildrenCount";
	[messageGroupsController bind:@"rootItem" toObject:self withKeyPath:@"messageGroupHierarchyRootNode" options:options];
	
	[messageTextView setEditable:NO];
	NSAssert(![messageTextView isEditable], @"should be non editable");
	
	[self.window makeKeyAndOrderFront:self];
}

- (void)setThreadsOnlyMode
{
	if ([threadMailSplitter isSubviewCollapsed:[[threadsOutlineView superview] superview]])
	{
		NSLog(@"only mail visible. switching to only threads visible.");
		[threadMailSplitter setPosition:[threadMailSplitter frame].size.height ofDividerAtIndex:0];
		[self.window makeFirstResponder:threadsOutlineView];
	}
}

- (BOOL) isShowingThreadsOnly
{
	return [threadMailSplitter isSubviewCollapsed: mailTreeSplitter];
}

- (BOOL) isShowingMessageOnly
{
	BOOL result = [threadMailSplitter isSubviewCollapsed: threadsOutlineView];
	return result;
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

// -- handling message tree view selection --
- (IBAction) commentTreeSelectionChanged: (id) sender
{
	GIMessage* message = [commentTreeView selectedMessage];
	
	if (message) {
		[self showMessage: message];
	}
}

// -- handling menu commands --

- (GIProfile *)profileForMessage:(GIMessage *)aMessage
/*" Return the profile to use for email replies. Tries first to guess a profile based on the replied email. If no matching profile can be found, the group default profile is chosen. May return nil in case of no group default and no match present. "*/
{
    GIProfile *result;
    
    result = [GIProfile guessedProfileForReplyingToMessage:[aMessage internetMessage]];
    
    if (!result)
    {
        result = [[self selectedGroup] defaultProfile];
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
	
    [[[GIMessageEditorController alloc] initForward:message profile: [self profileForMessage:message]] autorelease];
}

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

- (IBAction)delete:(id)sender
{
	GIHierarchyNode *node = messageGroupsController.selectedObject;

	NSString *nodeType = [node isKindOfClass:[GIMessageGroup class]] ? NSLocalizedString(@"Mailbox", @"Delete warning dialog") : NSLocalizedString(@"Folder", @"Delete warning dialog");
	NSAlert *alert = [[NSAlert alloc] init];
	
	[alert addButtonWithTitle:NSLocalizedString(@"Delete", @"Delete warning dialog")];
	[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Delete warning dialog")];
	[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Delete %@ '%@' and all of its contents?", @"Delete warning dialog"), nodeType, node.name]];
	[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"The deleted %@ cannot be restored.", @"Delete warning dialog"), nodeType]];
	[alert setAlertStyle:NSWarningAlertStyle];	
	
	if ([alert runModal] == NSAlertFirstButtonReturn) 
	{
		// Delete clicked, delete the node
		[self.messageGroupsController deleteHierarchyNode:node];
	}
	
	[alert release];
}

- (IBAction)markAsRead:(id)sender
{
	for (GIMessage *message in [threadsController selectedMessages]) 
	{
		message.isSeen = YES;
	}
}

- (IBAction)markAsUnread:(id)sender
{
	for (GIMessage *message in [threadsController selectedMessages]) 
	{
		message.isSeen = NO;
	}
}

- (IBAction)toggleRead:(id)sender
{
	if ([threadsController selectionHasUnreadMessages]) 
	{
		[self markAsRead:self];
	} 
	else 
	{
		[self markAsUnread:self];
	}
}

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

- (void) showMessage: (GIMessage*) message
/*" Tries to show the message given. Selects any group the thread is in. "*/
{
	GIMessageGroup* group = message.thread.messageGroups.lastObject;
	if (group) {
		// select group:
		[messageGroupsController setSelectedItemsPaths: [NSArray arrayWithObject: [NSArray arrayWithObject: group]] byExtendingSelection: NO];
		// expand thread, if necessary:
		NSArray* itemPath =  (message.thread.messageCount > 1) ? [NSArray arrayWithObjects: message.thread, message, nil] : [NSArray arrayWithObjects: message.thread, nil];

		[threadsController setSelectedItemsPaths: [NSArray arrayWithObject: itemPath] byExtendingSelection: NO];
	}
	[threadsOutlineView.window makeFirstResponder: threadsOutlineView];
}

- (BOOL)validateUserInterfaceItem:(id < NSValidatedUserInterfaceItem >)anItem
{
	SEL action = [anItem action];
	
	if (action == @selector(delete:))
	{
		return [(GIHierarchyNode *)[messageGroupsController selectedObject] isDeletable];
	}
	else if (action == @selector(markAsRead:))
	{
		return [threadsController selectionHasUnreadMessages];
	}
	else if (action == @selector(markAsUnread:))
	{
		return [threadsController selectionHasReadMessages];
	}
	else if (action == @selector(toggleRead:))
	{
		return [[threadsController selectedObjects] count] != 0;
	}
	else if (action == @selector(replyAll:) || action == @selector(replySender:) || action == @selector(forward:))
	{
		return [self selectedMessage] && [threadsController selectedObjects].count == 1;
	}
	
	return YES;
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)theItem
{
	return [self validateUserInterfaceItem:theItem];
}

@end

@implementation GIMainWindowController (GeneralBindings)

- (NSArray *)messageGroupHierarchyRootNodes
{
	return [[GIHierarchyNode messageGroupHierarchyRootNode] children];
}

- (NSArray*) messageGroupHierarchyRootNode
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

- (CGFloat)splitView:(NSSplitView *)sender constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset
{
	if (sender == threadMailSplitter)
	{
		CGFloat result = [sender frame].size.height - 125.0;
		return result;
	}
	return proposedMax;
}

- (CGFloat)splitView:(NSSplitView *)sender constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset
{
	if (sender == threadMailSplitter)
	{
		return 17.0;
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
			[self performSetSeenBehaviorForMessage:self.selectedMessage];
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

@implementation GIMainWindowController (OutlineViewDelegateAndActions)

- (IBAction)threadsDoubleAction:(id)sender
{
	unsigned messageSendStatus = [[self selectedMessage] sendStatus];
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
	else if ([threadMailSplitter isSubviewCollapsed:mailTreeSplitter])
	{
		// show message view and graphical thread view:
		[threadMailSplitter setPosition:0.0 ofDividerAtIndex:0];
		[self.window makeFirstResponder:(NSResponder *)messageTextView];
		[self performSetSeenBehaviorForMessage:self.selectedMessage];
	}
	else
	{
		NSLog(@"NOT collapsed. Ignoring");
	}
}

@end

@implementation GIMainWindowController (BindingStuff)
// -- binding stuff --

+ (void)initialize
{
    [self exposeBinding:@"selectedThreads"];	
}

- (Class)valueClassForBinding:(NSString *)binding
{
	return [NSArray class];
}

- (id)observedObjectForSelectedThreads { return observedObjectForSelectedThreads; }
- (void)setObservedObjectForSelectedThreads:(id)anObservedObjectForSelectedThreads
{
    if (observedObjectForSelectedThreads != anObservedObjectForSelectedThreads) 
	{
        [observedObjectForSelectedThreads release];
        observedObjectForSelectedThreads = [anObservedObjectForSelectedThreads retain];
    }
}

- (NSString *)observedKeyPathForSelectedThreads { return observedKeyPathForSelectedThreads; }
- (void)setObservedKeyPathForSelectedThreads:(NSString *)anObservedKeyPathForSelectedThreads
{
    if (observedKeyPathForSelectedThreads != anObservedKeyPathForSelectedThreads) 
	{
        [observedKeyPathForSelectedThreads release];
        observedKeyPathForSelectedThreads = [anObservedKeyPathForSelectedThreads copy];
    }
}

- (void)bind:(NSString *)bindingName
    toObject:(id)observableController
 withKeyPath:(NSString *)keyPath
     options:(NSDictionary *)options
{	
    if ([bindingName isEqualToString:@"selectedThreads"])
    {
		// observe the controller for changes
		[observableController addObserver:self
							   forKeyPath:keyPath 
								  options:0
								  context:nil];
		
		// register what controller and what keypath are 
		// associated with this binding
		[self setObservedObjectForSelectedThreads:observableController];
		[self setObservedKeyPathForSelectedThreads:keyPath];	
    }
	
	[super bind:bindingName
	   toObject:observableController
	withKeyPath:keyPath
		options:options];
}

- (void)unbind:bindingName
{
    if ([bindingName isEqualToString:@"selectedThreads"])
    {
		[observedObjectForSelectedThreads removeObserver:self
									   forKeyPath:observedKeyPathForSelectedThreads];
		[self setObservedObjectForSelectedThreads:nil];
		[self setObservedKeyPathForSelectedThreads:nil];
    }	
	
	[super unbind:bindingName];
}

- (void)observeValueForKeyPath:(NSString *)keyPath 
					  ofObject:(id)object 
						change:(NSDictionary *)change 
					   context:(void *)context
{
	if ([keyPath isEqualToString:[self observedKeyPathForSelectedThreads]])
	{ 
		// selected threads changed
		id newSelectedThreads = [observedObjectForSelectedThreads valueForKeyPath:observedKeyPathForSelectedThreads];
		[self setSelectedThreads:newSelectedThreads];
		
		if (!self.isShowingThreadsOnly)
		{
			GIMessage *selectedMessage = self.selectedMessage;		
			[self performSetSeenBehaviorForMessage:selectedMessage];
		}
		return;
	}

	[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}


@end

@implementation GIMainWindowController (KeyboardShortcuts)

#define LEFT_A 0
#define DOWN_S 1
#define RIGHT_D 2
#define UP_W 13
#define ESC 53
#define BACKSPACE 51
#define RETURN 36
#define SPACE 49

- (BOOL)keyPressed:(NSEvent *)event
{
	int keyCode = event.keyCode;
	switch(keyCode)
	{
		case LEFT_A:
			[commentTreeView navigateLeftInMatrix:self];
			return YES;
		case DOWN_S:
			[commentTreeView navigateDownInMatrix:self];
			return YES;
		case RIGHT_D:
			[commentTreeView navigateRightInMatrix:self];
			return YES;
		case UP_W:
			[commentTreeView navigateUpInMatrix:self];
			return YES;
		case ESC:
		case BACKSPACE:
		{
			// if only mail is visible, switch back to only thread list visible
			NSLog(@"subviews of thread mail splitter = %@", [threadMailSplitter subviews]);
			NSLog(@"[threadsOutlineView superview] = %@", [[threadsOutlineView superview] superview]);
			
			[self setThreadsOnlyMode];
			return YES;
		}
		case RETURN:
			if ([self.window firstResponder] == threadsOutlineView)
			{
				[self threadsDoubleAction:threadsOutlineView];
				return YES;
			}
			break;
		default:
			break;
	}
	
	return NO;
}

@end

@implementation GIMainWindowController (StatusPane)

- (BOOL)showsStatusPane
{
#warning dummy for now (status/progress pane)
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
