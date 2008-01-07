//
//  GIMainWindowController.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 12.10.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import "GIMainWindowController.h"
#import "OPOutlineViewController.h"

#import "GIUserDefaultsKeys.h"

// helper
#import <Foundation/NSDebug.h>
#import "NSArray+Extensions.h"
#import "NSAttributedString+Extensions.h"
#import "NSString+Extensions.h"

// model stuff
#import "OPPersistentObject.h"

//#import "GIMessageGroup+Statistics.h"
#import "GIThread.h"
#import "GIMessage.h"
#import "GIMessage+Rendering.h"
#import "GIHierarchyNode.h"
#import "GIMessageGroup.h"

//static NSString *ContentContext = @"ContentContext";
static NSString *SelectedThreadsContext = @"SelectedThreadsContext";

static inline NSString *nilGuard(NSString *str)
{
    return str ? str : @"";
}

// diverse attributes
static NSDictionary *unreadAttributes()
{
    static NSDictionary *attributes = nil;
    
    if (! attributes)
	{
        attributes = [[NSDictionary alloc] initWithObjectsAndKeys:
					  [NSFont boldSystemFontOfSize:12], NSFontAttributeName,
					  nil];
    }
    return attributes;
}

static NSDictionary *readAttributes()
{
    static NSDictionary *attributes = nil;
    
    if (! attributes) 
	{
        attributes = [[NSDictionary alloc] initWithObjectsAndKeys:
					  [NSFont systemFontOfSize:12], NSFontAttributeName,
					  nil];
    }
    return attributes;
}

static NSDictionary *newAttributesWithColor(NSColor *color) 
{
	NSDictionary* attributes = [[NSDictionary alloc] initWithObjectsAndKeys:
								[NSFont systemFontOfSize: 12], NSFontAttributeName,
								color, NSForegroundColorAttributeName, 
								nil, nil];
	return attributes;
}


static NSDictionary *spamMessageAttributes()
{
    static NSDictionary *attributes = nil;
    
    if (! attributes) 
	{
        attributes = newAttributesWithColor([[NSColor brownColor] highlightWithLevel:0.0]);
    }
    return attributes;
}

static NSDictionary *fromAttributes()
{
	return readAttributes();
	
//    static NSDictionary *attributes = nil;
//    
//    if (! attributes) 
//	{
//        attributes = newAttributesWithColor([[NSColor darkGrayColor] shadowWithLevel:0.3]);
//    }
//    return attributes;
}

static NSDictionary *unreadFromAttributes()
{
	//return fromAttributes();
	return unreadAttributes();
}

static NSDictionary *readFromAttributes()
{
    static NSDictionary *attributes = nil;
    
    if (! attributes) 
	{
        attributes = [[fromAttributes()mutableCopy] autorelease];
        [(NSMutableDictionary *)attributes addEntriesFromDictionary:readAttributes()];
        attributes = [attributes copy];
    }
    return attributes;
}

/*" String for inserting for message inset. "*/
static NSAttributedString *spacer()
{
    static NSAttributedString *spacer = nil;
    if (! spacer)
	{
        spacer = [[NSAttributedString alloc] initWithString:@"     "];
    }
    return spacer;
}

NSDateFormatter *timeAndDateFormatter()
{
	static NSDateFormatter *timeAndDateFormatter = nil;
	
	if (!timeAndDateFormatter)
	{
		timeAndDateFormatter = [[NSDateFormatter alloc] init];
		[timeAndDateFormatter setDateStyle:NSDateFormatterShortStyle];
		[timeAndDateFormatter setTimeStyle:NSDateFormatterShortStyle];
	}
	
	return timeAndDateFormatter;
}

@implementation GIMessage (ThreadControllerExtensions)

- (NSAttributedString *)renderedMessage
{
	NSAttributedString *result;
	BOOL showRawSource = [[NSUserDefaults standardUserDefaults] boolForKey:ShowRawSource];;
	
	if (showRawSource) 
	{
		NSData *transferData = [[self internetMessage] transferData];
		NSString *transferString = [NSString stringWithData:transferData encoding:NSUTF8StringEncoding];
		
		static NSDictionary *fixedFont = nil;
		
		if (!fixedFont) 
		{
			fixedFont = [[NSDictionary alloc] initWithObjectsAndKeys:[NSFont userFixedPitchFontOfSize:10], NSFontAttributeName, nil, nil];
		}
		
		// joerg: this is a quick hack (but seems sufficient here) to handle 8 bit transfer encoded messages (body) without having to do the mime parsing
		if (! transferString) 
		{
			transferString = [NSString stringWithData:transferData encoding:NSISOLatin1StringEncoding];
		}
		
		result = [[[NSAttributedString alloc] initWithString:transferString attributes:fixedFont] autorelease]; 
	} 
	else 
	{
		result = [self renderedMessageIncludingAllHeaders:[[NSUserDefaults standardUserDefaults] boolForKey:ShowAllHeaders]];
	}
	
	if (!result) 
	{
		result = [[NSAttributedString alloc] initWithString:@"Warning: Unable to decode message. messageText == nil."];
	}
	
	return result;
}

@end

@interface GIMessage (private)
- (id)renderedMessage;
@end

@implementation GIMessageGroup (copying)
- (id)copyWithZone:(NSZone *)aZone
{
	return [self retain];
}
@end

@interface GIThread (ThreadViewSupport)
- (GIMessage *)message;
- (OPFaultingArray *)threadChildren;
- (id)subjectAndAuthor;
- (NSAttributedString *)messageForDisplay;
- (NSAttributedString *)dateForDisplay;
- (NSImage *)statusImage;
@end

@implementation GIThread (ThreadViewSupport)

- (OPFaultingArray *)threadChildren
{
	OPFaultingArray *threadChildren = [self messagesByTree];
	
	if ([threadChildren count] > 1)
	{
		// multi-message thread
		return threadChildren;
	}
	else
	{
		// single-message thread
		return nil;
	}
}

- (id)subjectAndAuthor
{
	OPFaultingArray *msgs = [self messagesByTree];

	if ([msgs count] > 1)
	{
		// multi-message thread
		return [[[NSAttributedString alloc] initWithString:nilGuard([self valueForKey:@"subject"]) attributes:[self hasUnreadMessages] ? unreadAttributes() : readAttributes()] autorelease];
	}	
	else
	{
		// single-message thread
		NSString *from;
		NSAttributedString *aFrom;
		GIMessage *message = [[self valueForKey:@"messages"] lastObject];
		NSMutableAttributedString *result = [[[NSMutableAttributedString alloc] init] autorelease];
				
		if (message) 
		{
			unsigned flags  = [message flags];
			NSString *subjectString = nilGuard([message valueForKey:@"subject"]);
			
			NSAttributedString *aSubject = [[NSAttributedString alloc] initWithString:nilGuard(subjectString) attributes:(flags & OPSeenStatus) ? readAttributes() : unreadAttributes()];
			
			[result appendAttributedString:aSubject];
			
			if (flags & OPIsFromMeStatus) 
			{
				from = [NSString stringWithFormat:@" (%C %@)", 0x279F/*Right Arrow*/, [message recipientsForDisplay]];
			} 
			else 
			{
				from = [message senderName];
				if (!from) from = @"- sender missing -";
				from = [NSString stringWithFormat:@" (%@)", from];
			}       
			NSDictionary *completeAttributes = ((flags & OPSeenStatus) || (flags & OPIsFromMeStatus)) ? readFromAttributes() : unreadFromAttributes();
			
			if (flags & OPJunkMailStatus) 
			{
				completeAttributes = spamMessageAttributes();
			}
			
			aFrom = [[NSAttributedString alloc] initWithString:nilGuard(from) attributes:completeAttributes];
			
			[result appendAttributedString:aFrom];
			
			[aSubject release];
			[aFrom release];
		}
		
		return result;
	}
}

- (GIMessage *)message
{
	OPFaultingArray *msgs = [self messagesByTree];
	if ([msgs count] == 1)
	{
		return [msgs lastObject];
	}
	else
	{
		return nil;
	}
}

- (NSAttributedString *)messageForDisplay
{
	GIMessage *message = [self message];

	if (message)
	{
		// single-message thread
		return [message renderedMessage];
	}	
	else
	{
		// multi-message thread
		NSMutableAttributedString *result = [[[NSMutableAttributedString alloc] init] autorelease];
		
		if (NO) //[messagesByTree count] > 0)
		{
			[result appendString:[NSString stringWithFormat:@"\nThread '%@':\n", [[self subjectAndAuthor] string]]];
			[result appendString:[NSString stringWithFormat:@"contains %d messages\n", [[self messages] count]]];
		}
		return result;
	}
}

- (NSAttributedString *)dateForDisplay
{
	BOOL isRead = ![self hasUnreadMessages];
	
	NSString *dateString = [timeAndDateFormatter() stringFromDate:[self valueForKey:@"date"]];
		
	return [[[NSAttributedString alloc] initWithString:nilGuard(dateString) attributes:isRead ? readAttributes() : unreadAttributes()] autorelease];
}

- (NSImage *)statusImage
{
	if ([self hasUnreadMessages]) return [NSImage imageNamed:@"unread"];
	return nil;
}

@end

@interface GIMessage (ThreadViewSupport)
- (GIMessage *)message;
- (NSArray *)threadChildren;
- (id)subjectAndAuthor;
- (NSAttributedString *)messageForDisplay;
- (NSImage *)statusImage;
@end

@implementation GIMessage (ThreadViewSupport)

- (GIMessage *)message
{
	return self;
}

- (NSArray *)threadChildren
{
	return nil;
}

- (id)subjectAndAuthor
{
	//	return [NSString stringWithFormat:@"    %@", [self valueForKey:@"senderName"]];
	NSMutableAttributedString *result = [[[NSMutableAttributedString alloc] init] autorelease];
	NSString *from = [self senderName];
	
	if (!from) 
	{
		from = @"- sender missing -";
	}
	
	
	[result appendAttributedString:spacer()];
//	NSUInteger indentation = [self numberOfReferences];
	
//	for (i = MIN(MAX_INDENTATION, indentation); i > 0; i--) 
//	{
//		[result appendAttributedString:spacer()];
//	}
//	
//	[result appendAttributedString: (indentation > MAX_INDENTATION)? spacer2() : spacer()];
	
	NSDictionary *completeAttributes = ([self flags] & OPSeenStatus) ? readAttributes() : unreadAttributes();
	
	if (flags & OPJunkMailStatus) 
	{
		completeAttributes = spamMessageAttributes();
	}
	
	[result appendAttributedString:[[[NSAttributedString alloc] initWithString:nilGuard(from) attributes:completeAttributes] autorelease]];
	
	return result;
}

- (NSAttributedString *)messageForDisplay
{
	return [self renderedMessage];
}

- (NSAttributedString *)dateForDisplay
{
	BOOL isRead = [self hasFlags:OPSeenStatus];
	
	NSString *dateString = [timeAndDateFormatter() stringFromDate:[self valueForKey:@"date"]];
	
	return [[[NSAttributedString alloc] initWithString:nilGuard(dateString) attributes:isRead ? readAttributes() : unreadAttributes()] autorelease];
}

- (NSImage *)statusImage
{
	if (!self.isSeen) return [NSImage imageNamed:@"unread"];
	return nil;
}

@end

@implementation GIMainWindowController

+ (NSSet *)keyPathsForValuesAffectingMessageForDisplay
{
	return [NSSet setWithObject:@"selectedThreads"];
}
- (NSArray *)selectedThreads
{
	return selectedThreads;
}

- (void)setSelectedThreads:(NSArray *)someThreads
{
	NSLog(@"selected threads = %@", someThreads);
	selectedThreads = someThreads;
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

- (id)init
{
	self = [self initWithWindowNibName:@"MainWindow"];
		
	// receiving update notifications:
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	[notificationCenter addObserver:self selector:@selector(groupsChanged:) name:GIMessageGroupWasAddedNotification object:nil];
	[notificationCenter addObserver:self selector:@selector(groupsChanged:) name:GIMessageGroupsChangedNotification object:nil];
//	[notificationCenter addObserver:self selector:@selector(groupsChanged:) name:GIMessageGroupStatisticsDidUpdateNotification object:nil];
//	[notificationCenter addObserver:self selector:@selector(groupStatsInvalidated:) name:GIMessageGroupStatisticsDidInvalidateNotification object:nil];

	[self showWindow:self];

	return self;
}

- (void)dealloc
{
//	[threadTreeController removeObserver:self forKeyPath:@"content"];
//	[threadTreeController removeObserver:self forKeyPath:@"selectedObjects"];
	
	[super dealloc];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (object == threadsController)
	{
//		if (context == ContentContext)
//		{
//			if ([[threadTreeController content] count])
//			{
//				[threadTreeController setPreservesSelection:NO];
//				[threadTreeController invalidateThreadSelectionCache];
//				[threadTreeController setSelectionIndexPaths:[threadTreeController recallThreadSelectionForGroup:[[messageGroupTreeController selectedObjects] lastObject]]];
//			}
//		}
//		else 
		if (context == SelectedThreadsContext)
		{
			int setSeenBehavior = [[NSUserDefaults standardUserDefaults] integerForKey:SetSeenBehavior];
			NSArray *selectedObjects = [threadsController selectedObjects];
			[self setSelectedThreads:selectedObjects];
			
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
			
			if ([selectedObjects count] == 1)
			{
				selectedMessage = [(GIThread *)[selectedObjects lastObject] message];
			}
			
			if (NSDebugEnabled) NSLog(@"Thread/Message selection changed. %@", selectedMessage);

			switch(setSeenBehavior)
			{
				case GISetSeenBehaviorImmediately:
				{
					if (selectedMessage && (![selectedMessage hasFlags:OPSeenStatus]))
					{
						[selectedMessage setIsSeen:yesNumber];
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
	}
	else
	{
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (void)windowDidLoad
{
	// configuring manual bindings:
	NSDictionary *options = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES]
														forKey:NSAllowsEditingMultipleValuesSelectionBindingOption];
	
	[threadsController setChildKey:@"threadChildren"];
	[threadsController bind:@"rootItem" toObject:messageGroupTreeController withKeyPath:@"selection.self" options:options];
	
	[threadsController addObserver:self forKeyPath:@"selectedObjects" options:NSKeyValueObservingOptionNew |NSKeyValueObservingOptionOld context:SelectedThreadsContext];

//	[threadsController bind:@"selectedObjects" toObject:self withKeyPath:@"selectedThreads" options:options];
	
	 
//	[commentTreeView bind:@"selectedMessage" toObject:threadTreeController withKeyPath:@"selection.self" options:options];
	[commentTreeView setTarget:self];
	[commentTreeView setAction:@selector(commentTreeSelectionChanged:)];
	
	// configuring thread view:
	[threadsOutlineView setHighlightThreads:YES];
	[threadsOutlineView setDoubleAction:@selector(threadsDoubleAction:)];
	[threadsOutlineView setTarget:self];
	
//	[threadTreeController addObserver:self forKeyPath:@"content" options:0 context:ContentContext];
//	[threadTreeController addObserver:self forKeyPath:@"selectedObjects" options:NSKeyValueObservingOptionNew |NSKeyValueObservingOptionOld context:SelectedThreadsContext];
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
	/*
	GIMessage *message = [commentTreeView selectedMessage];
	
	if (message)
	{
		NSUInteger indexes[2];
		
		indexes[0] = [[threadTreeController selectionIndexPath] indexAtPosition:0];
		indexes[1] = [[[message thread] messagesByTree] indexOfObjectIdenticalTo:message];
		NSAssert(indexes[1] != NSNotFound, @"message should be found");

		NSIndexPath *indexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
		[threadTreeController setSelectionIndexPath:indexPath];
	}
	else
	{
		[threadTreeController setSelectionIndexPaths:[NSArray array]];
	}
	 */
}

// -- handling menu commands --

- (IBAction)markAsRead:(id)sender
{
/*	[[threadTreeController selectedMessages] makeObjectsPerformSelector:@selector(setIsSeen:) withObject:[NSNumber numberWithBool:YES]];
	[threadTreeController rearrangeSelectedNodes];
 */
}

- (IBAction)markAsUnread:(id)sender
{
	/*
	[[threadTreeController selectedMessages] makeObjectsPerformSelector:@selector(setIsSeen:) withObject:[NSNumber numberWithBool:NO]];
	[threadTreeController rearrangeSelectedNodes];
	 */
}

- (IBAction)toggleRead:(id)sender
{
	/*
	if ([threadTreeController selectionHasUnreadMessages])
	{
		[self markAsRead:self];
	}
	else
	{
		[self markAsUnread:self];
	}
	 */
}

/*
- (BOOL)validateToolbarItem:(NSToolbarItem *)theItem
{
	SEL action = [theItem action];
	
	if (action == @selector(markAsRead:))
	{
		return [threadTreeController selectionHasUnreadMessages];
	}

	if (action == @selector(markAsUnread:))
	{
		return [threadTreeController selectionHasReadMessages];
	}
	
	return YES;
}
*/

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

- (NSArray *)threadTreeSelectionIndexPaths
{
	/*
	[threadTreeController setPreservesSelection:YES];
	return [threadTreeController recallThreadSelectionForGroup:[[messageGroupTreeController selectedObjects] lastObject]];
	 */
	return nil;
}

- (void)setThreadTreeSelectionIndexPaths:(NSArray *)somePaths
{
//	[threadTreeController rememberThreadSelectionForGroup:[[messageGroupTreeController selectedObjects] lastObject]];
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

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	// item is tree node!
	
	if ([cell interiorBackgroundStyle] == NSBackgroundStyleDark)
	{
		if ([cell isKindOfClass:[NSTextFieldCell class]])
		{
			//	[cell setTextColor:[NSColor grayColor]];
			// change text to all white:
			//[(NSCell *)cell 
			//	NSLog(@"willDisplayCell dark item = %@", item);
		}
	}
	//	[super outlineView:outlineView willDisplayCell:cell forTableColumn:tableColumn item:item];
}

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