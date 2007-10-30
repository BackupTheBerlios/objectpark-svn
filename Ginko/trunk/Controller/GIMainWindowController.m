//
//  GIMainWindowController.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 12.10.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import "GIMainWindowController.h"
#import "GIUserDefaultsKeys.h"

// helper
#import "NSArray+Extensions.h"
#import "NSAttributedString+Extensions.h"

// model stuff
#import "GIMessageGroup+Statistics.h"
#import "GIThread.h"
#import "GIMessage.h"

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
- (NSArray *)children;
- (id)subjectAndAuthor;
- (NSAttributedString *)messageForDisplay;
- (NSAttributedString *)dateForDisplay;
- (NSImage *)statusImage;
@end

@implementation GIThread (ThreadViewSupport)

- (NSArray *)children
{
	NSArray *messagesByTree = [self messagesByTree];
	
	if ([messagesByTree count] > 1)
	{
		// multi-message thread
		return messagesByTree;
	}
	else
	{
		// single-message thread
		return nil;
	}
}

- (id)subjectAndAuthor
{
	NSArray *messagesByTree = [self messagesByTree];

	if ([messagesByTree count] > 1)
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
			NSString *subject = nilGuard([message valueForKey:@"subject"]);
			
			NSAttributedString *aSubject = [[NSAttributedString alloc] initWithString:nilGuard(subject) attributes:(flags & OPSeenStatus) ? readAttributes() : unreadAttributes()];
			
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

- (NSAttributedString *)messageForDisplay
{
	NSArray *messagesByTree = [self messagesByTree];

	if ([messagesByTree count] > 1)
	{
		// multi-message thread
		NSMutableAttributedString *result = [[[NSMutableAttributedString alloc] init] autorelease];
		
		if (NO) //[messagesByTree count] > 0)
		{
			[result appendString:[NSString stringWithFormat:@"\nThread '%@':\n", [[self subjectAndAuthor] string]]];
			[result appendString:[NSString stringWithFormat:@"contains %d messages\n", [messagesByTree count]]];
		}
		return result;
	}
	else
	{
		// single-message thread
		return [[messagesByTree lastObject] renderedMessage];
	}
}

- (NSAttributedString *)dateForDisplay
{
	BOOL isRead = ![self hasUnreadMessages];
	
	NSDate *date = [self valueForKey:@"date"]; // both thread an message respond to "date"	
	NSString *dateString = [timeAndDateFormatter() stringFromDate:date];
		
	return [[[NSAttributedString alloc] initWithString:nilGuard(dateString) attributes:isRead ? readAttributes() : unreadAttributes()] autorelease];
}

- (NSImage *)statusImage
{
	if ([self hasUnreadMessages]) return [NSImage imageNamed:@"unread"];
	return nil;
}

@end

@interface GIMessage (ThreadViewSupport)
- (NSArray *)children;
- (id)subjectAndAuthor;
- (NSAttributedString *)messageForDisplay;
- (NSImage *)statusImage;
@end

@implementation GIMessage (ThreadViewSupport)

- (NSArray *)children
{
	return nil;
}

- (id)subjectAndAuthor
{
	//	return [NSString stringWithFormat:@"    %@", [self valueForKey:@"senderName"]];
	NSMutableAttributedString *result = [[[NSMutableAttributedString alloc] init] autorelease];
	NSString *from = [self senderName];
	BOOL flags  = [self flags];
	
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
	
	NSDictionary *completeAttributes = (flags & OPSeenStatus) ? readAttributes() : unreadAttributes();
	
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
	
	NSDate *date = [self valueForKey:@"date"]; // both thread an message respond to "date"	
	NSString *dateString = [timeAndDateFormatter() stringFromDate:date];
	
	return [[[NSAttributedString alloc] initWithString:nilGuard(dateString) attributes:isRead ? readAttributes() : unreadAttributes()] autorelease];
}

- (NSImage *)statusImage
{
	if (![self hasFlags:OPSeenStatus]) return [NSImage imageNamed:@"unread"];
	return nil;
}

@end

@interface GIMessageGroup (MessageGroupHierarchySupport)
- (NSArray *)children;
- (NSNumber *)count;
@end

@implementation GIMessageGroup (MessageGroupHierarchySupport)

- (NSArray *)children
{
	return nil;
}

- (NSNumber *)count
{
	return [NSNumber numberWithInt:0];
}

@end

@interface NSArray (MessageGroupHierarchySupport)
- (NSDictionary *)messageGroupHierarchyAsDictionaries;
@end

@implementation NSArray (MessageGroupHierarchySupport)

- (NSDictionary *)messageGroupHierarchyAsDictionaries
{
	NSMutableArray *children = [NSMutableArray array];
	if ([self count] >= 2) 
	{
		NSEnumerator *enumerator = [[self subarrayFromIndex:1] objectEnumerator];
		id object;
		
		while (object = [enumerator nextObject])
		{
			if ([object isKindOfClass:[NSArray class]])
			{
				[children addObject:[object messageGroupHierarchyAsDictionaries]];
			}
			else
			{
				GIMessageGroup *group = [OPPersistentObjectContext objectWithURLString:object resolve:YES];
				NSAssert1([group isKindOfClass:[GIMessageGroup class]], @"Object is not a GIMessageGroup object: %@", object);
				[children addObject:group];
			}
		}
	}
	
	return [NSDictionary dictionaryWithObjectsAndKeys:
		[[self objectAtIndex:0] objectForKey:@"name"], @"name",
		[[self objectAtIndex:0] objectForKey:@"uid"], @"uid",
		[NSNumber numberWithInt:[children count]], @"count",
		children, @"children",
		nil, nil];
}

@end

@implementation GIMainWindowController

- (NSArray *)messageGroupTreeSelectionIndexPaths
{
	return messageGroupTreeSelectionIndexPaths;
}

- (void)setMessageGroupTreeSelectionIndexPaths:(NSArray *)somePaths
{
	NSLog(@"messageGroupTreeSelectionIndexPaths set to %@", somePaths);
	[messageGroupTreeSelectionIndexPaths autorelease];
	messageGroupTreeSelectionIndexPaths = [somePaths retain];
}

- (id)init
{
	self = [self initWithWindowNibName:@"MainWindow"];
	
	[GIMessageGroup loadGroupStats];
	
	// receiving update notifications:
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	[notificationCenter addObserver:self selector:@selector(groupsChanged:) name:GIMessageGroupWasAddedNotification object:nil];
	[notificationCenter addObserver:self selector:@selector(groupsChanged:) name:GIMessageGroupsChangedNotification object:nil];
	[notificationCenter addObserver:self selector:@selector(groupsChanged:) name:GIMessageGroupStatisticsDidUpdateNotification object:nil];
	[notificationCenter addObserver:self selector:@selector(groupStatsInvalidated:) name:GIMessageGroupStatisticsDidInvalidateNotification object:nil];

	[self loadWindow];

	// configuring message tree view:
	NSDictionary *options = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES]
														forKey:NSAllowsEditingMultipleValuesSelectionBindingOption];
	
	[commentTreeView bind:@"selectedMessage" toObject:threadTreeController withKeyPath:@"selection.self" options:options];
	[commentTreeView setTarget:self];
	[commentTreeView setAction:@selector(commentTreeSelectionChanged:)];
	
	// configuring thread view:
	[threadsOutlineView setHighlightThreads:YES];
	[[self window] makeKeyAndOrderFront:self];
	
	return self;
}

- (void)dealloc
{
	[messageGroupTreeSelectionIndexPaths release];
	[super dealloc];
}

- (void)windowDidLoad
{
	NSLog(@"windowDidLoad");
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
}

// -- handling menu commands --

- (IBAction)markAsRead:(id)sender
{
	[[threadTreeController selectedMessages] makeObjectsPerformSelector:@selector(setIsSeen:) withObject:[NSNumber numberWithBool:YES]];
	[threadTreeController rearrangeSelectedNodes];
}

- (IBAction)markAsUnread:(id)sender
{
	[[threadTreeController selectedMessages] makeObjectsPerformSelector:@selector(setIsSeen:) withObject:[NSNumber numberWithBool:NO]];
	[threadTreeController rearrangeSelectedNodes];
}

- (IBAction)toggleRead:(id)sender
{
	if ([threadTreeController selectionHasUnreadMessages])
	{
		[self markAsRead:self];
	}
	else
	{
		[self markAsUnread:self];
	}
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
	return [[[GIMessageGroup hierarchyRootNode] messageGroupHierarchyAsDictionaries] objectForKey:@"children"];
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
