//
//  GIMainWindowController.m
//  Gina
//
//  Created by Axel Katerbau on 12.10.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import "GIMainWindowController.h"
#import "GIThreadOutlineViewController.h"

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

+ (NSSet *)keyPathsForValuesAffectingMessageForDisplay
{
	return [NSSet setWithObject:@"selectedThreads"];
}

+ (NSSet *)keyPathsForValuesAffectingSelectedMessageOrThread
{
	return [NSSet setWithObject:@"selectedThreads"];
}

- (NSAttributedString *)messageForDisplay
{
	NSArray *threads = self.selectedThreads;
	if ([threads count] == 1)
	{
		return [[threads lastObject] messageForDisplay];
	}
	
	return nil;
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

- (id)init
{
	self = [self initWithWindowNibName:@"MainWindow"];
		
	// receiving update notifications:
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	[notificationCenter addObserver:self selector:@selector(groupsChanged:) name:GIMessageGroupWasAddedNotification object:nil];
	[notificationCenter addObserver:self selector:@selector(groupsChanged:) name:GIMessageGroupsChangedNotification object:nil];

	[self showWindow:self];

	return self;
}

- (void)dealloc
{
	[self unbind:@"selectedThreads"];
	[threadsController unbind:@"rootItem"];
	[commentTreeView unbind:@"selectedMessageOrThread"];
		
	[super dealloc];
}

- (void)windowDidLoad
{
	// configuring manual bindings:
	//NSDictionary *options = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES]
	//													forKey:NSAllowsEditingMultipleValuesSelectionBindingOption];
	NSDictionary *options = nil;
	
	[threadsController setChildKey:@"threadChildren"];
	[threadsController bind:@"rootItem" toObject:messageGroupTreeController withKeyPath:@"selection.self" options:options];
	
	[self bind:@"selectedThreads" toObject:threadsController withKeyPath:@"selectedObjects" options:options];
		
	[commentTreeView bind:@"selectedMessageOrThread" toObject:self withKeyPath:@"selectedMessageOrThread" options:options];
	[commentTreeView setTarget:self];
	[commentTreeView setAction:@selector(commentTreeSelectionChanged:)];
	
	// configuring thread view:
	[threadsOutlineView setHighlightThreads:YES];
	[threadsOutlineView setDoubleAction:@selector(threadsDoubleAction:)];
	[threadsOutlineView setTarget:self];
	
	[[self window] makeKeyAndOrderFront:self];
}

// --- change notification handling ---

- (void)groupsChanged:(NSNotification *)aNotification
{
    [messageGroupTreeController rearrangeObjects];
}

- (void)groupStatsInvalidated:(NSNotification *)aNotification
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(groupsChanged:) object:nil];
    [self performSelector:@selector(groupsChanged:) withObject:nil afterDelay:(NSTimeInterval)5.0];
}

// -- handling message tree view selection --
- (IBAction)commentTreeSelectionChanged:(id)sender
{
	GIMessage *message = [commentTreeView selectedMessage];
	
	if (message)
	{
		[threadsController setSelectedMessages:[NSArray arrayWithObject:message]];
	}
}

// -- handling menu commands --

- (IBAction)markAsRead:(id)sender
{
	for (GIMessage* message in [threadsController selectedMessages]) {
		message.isSeen = YES;
	}
}

- (IBAction) markAsUnread: (id) sender
{
	for (GIMessage* message in [threadsController selectedMessages]) {
		message.isSeen = NO;
	}
}

- (IBAction)toggleRead:(id)sender
{
	if ([threadsController selectionHasUnreadMessages]) {
		[self markAsRead: self];
	} else {
		[self markAsUnread: self];
	}
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)theItem
{
	SEL action = [theItem action];
	
	if (action == @selector(markAsRead:))
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
	
	return YES;
}

@end

@implementation GIMainWindowController (GeneralBindings)

- (NSArray *)messageGroupHierarchyRoot
{
	return [[GIHierarchyNode messageGroupHierarchyRootNode] children];
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
	CGFloat result = [sender frame].size.height - 125.0;
	return result;
}

- (CGFloat)splitView:(NSSplitView *)sender constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset
{
	return 17.0;
}

- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview
{
	return YES;
}

@end

@implementation GIMainWindowController (OutlineViewDelegateAndActions)

- (IBAction)threadsDoubleAction:(id)sender
{
	if ([threadMailSplitter isSubviewCollapsed:mailTreeSplitter])
	{
		NSLog(@"collapsed. switching views.");
		[threadMailSplitter setPosition:0.0 ofDividerAtIndex:0];
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
		
		int setSeenBehavior = [[NSUserDefaults standardUserDefaults] integerForKey:SetSeenBehavior];
		
		GIMessage *selectedMessage = nil;
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
		
		if ([[self selectedThreads] count] == 1)
		{
			selectedMessage = [(GIThread *)[[self selectedThreads] lastObject] message];
		}
		
		if (NSDebugEnabled) NSLog(@"Thread/Message selection changed. %@", selectedMessage);
		
		switch(setSeenBehavior)
		{
			case GISetSeenBehaviorImmediately:
			{
				if (selectedMessage && (![selectedMessage hasFlags:OPSeenStatus]))
				{
					[selectedMessage setIsSeen:YES];
				}
				break;
			}
			case GISetSeenBehaviorAfterTimeinterval:
			{
				if (selectedMessage && (![selectedMessage hasFlags:OPSeenStatus]))
				{
					[selectedMessage performSelector:@selector(setIsSeen:) withObject:yesNumber afterDelay:[[NSUserDefaults standardUserDefaults] floatForKey:SetSeenTimeinterval]];
					delayedMessage = selectedMessage;
				}
			}
			default:
				break;
		}
	}
	else
	{
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}	
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

- (BOOL)keyPressed:(NSEvent *)event
{
	switch([event keyCode])
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
			
			if ([threadMailSplitter isSubviewCollapsed:[[threadsOutlineView superview] superview]])
			{
				NSLog(@"only mail visible. switching to only threads visible.");
				@try
				{
					[threadMailSplitter setPosition:[threadMailSplitter frame].size.height ofDividerAtIndex:0];
				}
				@catch(id exception)
				{
					NSLog(@"exception: %@", exception);
				}
			}
			return YES;
		}
		case RETURN:
			break;
		default:
			break;
	}
	
	return NO;
}

@end