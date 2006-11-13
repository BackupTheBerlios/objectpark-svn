//
//  GIThreadsController.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 04.10.06.
//  Copyright 2006 Objectpark Group. All rights reserved.
//

#import "GIThreadsController.h"
#import "GIThread.h"
#import "GIMessage.h"
#import "GIMessage+Rendering.h"
#import "NSString+MessageUtils.h"
#import "GIUserDefaultsKeys.h"
#import "NSArray+Extensions.h"
#import "NSSplitView+Autosave.h"
#import "GICommentTreeView.h"
#import "GIMessageGroup.h"
#import "GIMessageBase.h"
#import "GIApplication.h"
#import "GIMessageEditorController.h"

NSString *GIThreadsControllerWillDeallocNotification = @"GIThreadsControllerWillDeallocNotification";

static NSDateFormatter *sharedDateFormatter = nil;

static NSDateFormatter *dateFormatter()
{
	if (!sharedDateFormatter)
	{
		sharedDateFormatter = [[NSDateFormatter alloc] init];
		[sharedDateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
		[sharedDateFormatter setDateStyle:NSDateFormatterShortStyle];
		[sharedDateFormatter setTimeStyle:NSDateFormatterShortStyle];
	}
	
	return sharedDateFormatter;
}

@implementation GIThread (ThreadControllerExtensions)

- (NSString *)messagesTitle
{
	int count = [[self valueForKey:@"messages"] count];
	
	NSString *format = count == 1 ? NSLocalizedString(@"%d Message:" , @"thread info 'thread messages' title") : NSLocalizedString(@"%d Messages:" , @"thread info 'thread messages' title");
	
	return [NSString stringWithFormat:format, count];
}

- (NSArray *)participants
{
	NSCountedSet *senderNames = [NSCountedSet set];
	
	NSEnumerator *enumerator = [[self valueForKey:@"messages"] objectEnumerator];
	GIMessage *message;
	
	while (message = [enumerator nextObject])
	{
		NSString *senderName = [message valueForKey:@"senderName"];
		if (senderName)
		{
			[senderNames addObject:senderName];
		}
	}
	
	NSMutableArray *result = [NSMutableArray array];
	enumerator = [senderNames objectEnumerator];
	NSString *senderName;
	
	while (senderName = [enumerator nextObject])
	{
		NSDictionary *entry = [NSDictionary dictionaryWithObjectsAndKeys:
			senderName, @"senderName",
			[NSNumber numberWithInt:[senderNames countForObject:senderName]], @"messageCount",
			nil, nil];
		
		[result addObject:entry];
	}
	
	return result;
}

- (NSString *)participantsTitle
{
	int count = [[self participants] count];
	
	NSString *format = count == 1 ? NSLocalizedString(@"%d Participant:" , @"thread info 'thread participants' title") : NSLocalizedString(@"%d Participants:" , @"thread info 'thread participants' title");
	
	return [NSString stringWithFormat:format, count];
}

- (NSString *)timeSpanDescription
{
	NSArray *messages = [self valueForKey:@"messages"];
	
	if ([messages count] == 0) return @"";
	
	GIMessage *firstMessage = [messages objectAtIndex:0];
	GIMessage *lastMessage = [messages lastObject];
	
	NSDate *firstDate = [firstMessage valueForKey:@"date"];
	NSDate *lastDate = [lastMessage valueForKey:@"date"];
	
	if ((firstMessage == lastMessage) || (lastDate == nil))
	{
		return [dateFormatter() stringForObjectValue:firstDate];
	}
	else
	{
		return [NSString stringWithFormat:@"%@ - %@", [dateFormatter() stringForObjectValue:firstDate], [dateFormatter() stringForObjectValue:lastDate]];
	}
}

- (unsigned)unreadMessageCount
{
    unsigned result = 0;
	NSEnumerator *enumerator = [[self messages] objectEnumerator];
	GIMessage *message;
    while (message = [enumerator nextObject]) 
	{
        if (![message hasFlags:OPSeenStatus]) 
		{
            result += 1;
        }
    }
	
    return result;
}

- (GIMessage *)firstUnreadMessage
{
	NSArray *messages = [self messagesByTree];
	NSEnumerator *enumerator = [messages objectEnumerator];
	GIMessage *message;
	
	while (message = [enumerator nextObject])
	{
		if (![message hasFlags:OPSeenStatus] && ![message isDummy])
		{
			break;
		}
	}
	
	return message;
}

- (NSString *)statistics
{
	return [NSString stringWithFormat:@"%u/%u", [self unreadMessageCount], [self messageCount]];
}

@end

@implementation GIMessage (ThreadControllerExtensions)

- (NSAttributedString *)renderedMessage
{
	NSAttributedString *result;
	BOOL showRawSource = [[NSUserDefaults standardUserDefaults] boolForKey:ShowRawSource];;
	
	if (showRawSource) 
	{
		NSData *transferData = [self transferData];
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

@interface GIThreadsController (ControllerStuff)

- (void)threadSelectionDidChange;

@end

@implementation GIThreadsController

+ (void)initialize
{
	[self setKeys:[NSArray arrayWithObjects:@"filterReadThreads", nil] triggerChangeNotificationsForDependentKey:@"threadsFilterPredicate"];
}

- (id)initWithThreads:(NSArray *)someThreads andAutosaveName:(NSString *)autosaveName
{
	if (self = [self initWithWindowNibName:@"Threads"])
	{
		[self setShouldCascadeWindows:NO];
		
		if (!autosaveName)
		{
			autosaveName = @"Threads";
		}
		else
		{
			autosaveName = [@"Threads-" stringByAppendingString:autosaveName];
		}
		
		[self setWindowFrameAutosaveName:autosaveName];

		[self setThreads:someThreads];
		
		[self window]; // making sure the bindings are active
	}
	
	return [self retain];
}

- (id)initWithGroup:(GIMessageGroup *)aGroup andAutosaveName:(NSString *)autosaveName
{
	if (self = [self initWithWindowNibName:@"Threads"])
	{
		[self setShouldCascadeWindows:NO];
		
		if (!autosaveName)
		{
			autosaveName = @"Threads";
		}
		else
		{
			autosaveName = [@"Threads-" stringByAppendingString:autosaveName];
		}
		
		[self setWindowFrameAutosaveName:autosaveName];
		
		[self setGroup:aGroup];
		
		[self window]; // making sure the bindings are active
	}
	
	return [self retain];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[threads release];
	[defaultProfile release];
	[group release];
	
	[super dealloc];
}

- (void)windowWillClose:(NSNotification *)aNotification
{
	[[NSNotificationCenter defaultCenter] postNotificationName:GIThreadsControllerWillDeallocNotification object:self];
	[self autorelease];
}

- (void)windowDidLoad
{
	// set up date formatters:
	[[threadDateColumn dataCell] setFormatter:dateFormatter()];
	[[messageDateColumn dataCell] setFormatter:dateFormatter()];
			
	// set up linebreak mode:
	[[subjectAndAuthorColumn dataCell] setLineBreakMode:NSLineBreakByTruncatingMiddle];
	
	// configure split views:
	[thread_messageSplitView setAutosaveName:[[self windowFrameAutosaveName] stringByAppendingString:@"-Thread-Messages"]];
	[thread_messageSplitView setAutosaveDividerPosition:YES];
	[verticalSplitView setAutosaveName:[[self windowFrameAutosaveName] stringByAppendingString:@"-Vertical"]];
	[verticalSplitView setAutosaveDividerPosition:YES];
	[infoSplitView setAutosaveName:[[self windowFrameAutosaveName] stringByAppendingString:@"-Info"]];
	[infoSplitView setAutosaveDividerPosition:YES];
	
	[commentTreeView setTarget:self];
	[commentTreeView setAction:@selector(commentTreeSelectionChanged:)];
	
	// configuring threads table view:
	[threadsTableView registerForDraggedTypes:[NSArray arrayWithObject:@"GinkoThreads"]];
	[threadsTableView setDraggingSourceOperationMask:NSDragOperationMove | NSDragOperationCopy forLocal:YES];
	[threadsTableView setDraggingSourceOperationMask:NSDragOperationMove | NSDragOperationCopy forLocal:NO];

	// registering for notifications:
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tableViewSelectionDidChange:) name:NSTableViewSelectionDidChangeNotification object:threadsTableView];
	
	// setting initial thread selection:
	int selectionIndex = [[threadsController arrangedObjects] count] -1;
	if (selectionIndex >= 0)
	{
		[threadsController setSelectionIndex:selectionIndex];
	}
	
	[self threadSelectionDidChange];
}

- (void)setThreads:(NSArray *)someThreads
{
//	if (someThreads != threads)
//	{
		int recents = [self numberOfRecentThreads];
		int threadCount = [someThreads count];
		
		if (recents && (threadCount > recents))
		{
			someThreads = [someThreads subarrayWithRange:NSMakeRange(threadCount - recents, recents)];
		}
				
		[someThreads retain];
		[threads release];
		threads = [someThreads retain];
		[self threadSelectionDidChange];
//	}
}

- (NSArray *)threads
{
	return threads;
}

- (void)setDefaultProfile:(GIProfile *)aProfile
{
	[defaultProfile autorelease];
	defaultProfile = [aProfile retain];
}

- (GIProfile *)defaultProfile
{
	return defaultProfile;
}

/*" Just for drag and drop and copy & paste support. May be nil. "*/
- (void)setGroup:(GIMessageGroup *)aGroup
{
	NSParameterAssert([aGroup isKindOfClass:[GIMessageGroup class]]);
	
	if (group != aGroup)
	{
		[group removeObserver:self forKeyPath:@"threadsByDate"];

		[group release];
		group = [aGroup retain];
		
		[self setThreads:[group valueForKey:@"threadsByDate"]];

		[group addObserver:self forKeyPath:@"threadsByDate" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object 
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if ([keyPath isEqual:@"threadsByDate"]) 
	{
		NSNumber *kind = [change objectForKey:NSKeyValueChangeKindKey];
				
#warning OPPersistence KVO is broken. Can't do the right thing here.
		if ([kind intValue]== NSKeyValueChangeSetting)
		{
			NSLog(@"OPPersistence KVO handling for to-many relationships still broken.");

			NSArray *groupThreads = [[self group] valueForKey:@"threadsByDate"];
			int recents = [self numberOfRecentThreads];
			int threadCount = [groupThreads count];
			
			if (recents && (threadCount > recents))
			{
				groupThreads = [groupThreads subarrayWithRange:NSMakeRange(threadCount - recents, recents)];
			}
			
			[self setThreads:groupThreads];
		}
		else
		{
			NSAssert(NO, @"OPPersistence KVO handling for to-many has been fixed.");
		}
    }
}

/*" Just for drag and drop and copy & paste support. May be nil. "*/
- (GIMessageGroup *)group
{
	return group;
}

- (void)setNumberOfRecentThreads:(int)numberOfRecentThreads
{
	[[NSUserDefaults standardUserDefaults] setInteger:numberOfRecentThreads forKey:[[self windowFrameAutosaveName] stringByAppendingString:@"-NumberOfRecentThreads"]];
	
	[self setThreads:[[self group] valueForKey:@"threadsByDate"]];
}

- (int)numberOfRecentThreads
{
	return [[NSUserDefaults standardUserDefaults] integerForKey:[[self windowFrameAutosaveName] stringByAppendingString:@"-NumberOfRecentThreads"]];
}

- (void)setFilterReadThreads:(BOOL)aBool
{
	[[NSUserDefaults standardUserDefaults] setBool:aBool forKey:[[self windowFrameAutosaveName] stringByAppendingString:@"-FilterReadThreads"]];
}

- (BOOL)filterReadThreads
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:[[self windowFrameAutosaveName] stringByAppendingString:@"-FilterReadThreads"]];
}

- (NSPredicate *)threadsFilterPredicate
{
	static NSPredicate *threadsFilterPredicate = nil;
	
	if (!threadsFilterPredicate)
	{
		threadsFilterPredicate = [[NSPredicate predicateWithFormat:@"hasUnreadMessages != 0"] retain];
	}
	
	if ([self filterReadThreads])
	{
		return threadsFilterPredicate;
	}
	else
	{
		return nil;
	}
}

/*" Selects the thread threadToSelect in the receiver and makes sure the selection is visible. "*/
- (void)selectThread:(GIThread *)threadToSelect
{
	[threadsController setSelectedObjects:[NSArray arrayWithObject:threadToSelect]];
	[self threadSelectionDidChange];
}

/*" Return the selected message or nil if more than one message is selected or no message is selected. "*/
- (GIMessage *)selectedMessage
{
	NSArray *selectedMessages = [messagesController selectedObjects];
	
	if ([selectedMessages count] == 1)
	{
		return [selectedMessages lastObject];
	}
	else
	{
		return nil;
	}
}

- (void)setSelectedMessage:(GIMessage *)aMessage
{
	[threadsController setSelectedObjects:[NSArray arrayWithObject:[aMessage thread]]];
	[messagesController setSelectedObjects:[NSArray arrayWithObject:aMessage]];
}

@end

@implementation GIThreadsController (ControllerStuff)

- (IBAction)commentTreeSelectionChanged:(id)sender
{
	GIMessage *message = [commentTreeView selectedMessage];
	
	if (message)
	{
		[messagesController setSelectedObjects:[NSArray arrayWithObject:message]];
	}
}

/*" Sets the message text view scroll and cursor position to the upper left corner. "*/
- (void)resetMessageTextView
{
	// set the insertion point (cursor)to 0, 0
	[messageTextView setSelectedRange:NSMakeRange(0, 0)];
	[messageTextView sizeToFit];
	// make sure that the message's header is displayed:
	[messageTextView scrollRangeToVisible:NSMakeRange(0, 0)];
}

- (void)threadSelectionDidChange
{
	BOOL selectFirstUnreadMessageInThread = [[NSUserDefaults standardUserDefaults] boolForKey:SelectFirstUnreadMessageInThread];
	
	if (selectFirstUnreadMessageInThread)
	{
		NSArray *messages = [messagesController arrangedObjects];
		NSEnumerator *enumerator = [messages objectEnumerator];
		GIMessage *message;
		
		while (message = [enumerator nextObject])
		{
			if (![message hasFlags:OPSeenStatus])
			{
				[messagesController setSelectedObjects:[NSArray arrayWithObject:message]];
				break;
			}
		}
		if (!message) // select last if all are read
		{
			message = [messages lastObject];
			
			if (message)
			{
				[messagesController setSelectedObjects:[NSArray arrayWithObject:message]];
			}
		}
	}
	
	NSArray *selectedThreads = [threadsController selectedObjects];
	
	if ([selectedThreads count] == 1)
	{
		[commentTreeView setThread:[selectedThreads lastObject]];
	}
	else
	{
		[commentTreeView setThread:nil];
	}
	
	[commentTreeView setSelectedMessage:[[messagesController selectedObjects] lastObject]];
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	[self resetMessageTextView];
	
	if ([[aNotification object] tag] == 0) // the thread table view
	{
		[self threadSelectionDidChange];
	}
	else // the message table view
	{
		[commentTreeView setSelectedMessage:[[messagesController selectedObjects] lastObject]];
	}
}

- (int)infoPanelTableViewFontSize
{
	return 10;
}

- (int)infoPanelTableViewRowHeight
{
	return 12;
}

- (int)threadsTableViewFontSize
{
	return 12;
}

- (int)threadsTableViewRowHeight
{
	return 16;
}

- (BOOL)isTextViewEditable
{
	return NO;
}

- (void)test
{
	[self setThreads:[[self threads] subarrayFromIndex:1]];
}

@end

@implementation GIThreadsController (UserActions)

/*" Returns YES if the message view was scrolled down. NO otherwise. "*/
- (BOOL)scrollMessageTextViewPageDown
{
	NSPoint currentScrollPosition = [[messageTextScrollView contentView] bounds].origin;

	if (currentScrollPosition.y == (NSMaxY([[messageTextScrollView documentView] frame]) 
									- NSHeight([[messageTextScrollView contentView] bounds]))) return NO;
	
	// scroll page down:
	float height = NSHeight([[messageTextScrollView contentView] bounds]);
	currentScrollPosition.y += height;
	if (height > (16 * 2)) // overlapping
	{
		currentScrollPosition.y -= 16;
	}
	
	if (currentScrollPosition.y > (NSMaxY([[messageTextScrollView documentView] frame]) 
								   - NSHeight([[messageTextScrollView contentView] bounds]))) 
	{
		currentScrollPosition.y = (NSMaxY([[messageTextScrollView documentView] frame]) 
								   - NSHeight([[messageTextScrollView contentView] bounds]));
	}
	
	[[messageTextScrollView documentView] scrollPoint:currentScrollPosition];

	return YES;
}

/*" Returns the next message appropriate for viewing (in this case the next unread which might be eventually change/be user customizable). Or nil if no such message can be found. "*/
- (GIMessage *)nextMessage
{
	int i;
	
	NSArray *arrangedMessages = [messagesController arrangedObjects];
	int selectedMessageIndex = [messagesController selectionIndex];
	
	if (selectedMessageIndex < 0) return nil;
	
	for (i = selectedMessageIndex + 1; i < [arrangedMessages count]; i++)
	{
		if (![[arrangedMessages objectAtIndex:i] hasFlags:OPSeenStatus])
		{
			return [arrangedMessages objectAtIndex:i];
		}
	}
	
	// try "next" thread
	NSArray *arrangedThreads = [threadsController arrangedObjects];
	int selectedThreadsIndex = [threadsController selectionIndex];
	
	if (selectedThreadsIndex < 0) return nil;
	
	for (i = selectedThreadsIndex + 1; i < [arrangedThreads count]; i++)
	{
		GIThread *thread = [arrangedThreads objectAtIndex:i];
		if ([thread hasUnreadMessages])
		{
			arrangedMessages = [messagesController arrangeObjects:[thread messages]];
			int j;
			
			for (j = 0; j < [arrangedMessages count]; j++)
			{
				if (![[arrangedMessages objectAtIndex:j] hasFlags:OPSeenStatus])
				{
					return [arrangedMessages objectAtIndex:j];
				}
			}
		}
	}
	
	return nil;
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
			[self setSelectedMessage:nextMessage];
		}
		else
		{
			NSBeep();
		}
	}
}

- (IBAction)goAheadAndMarkSeen:(id)sender
{
	// scroll message text view down if possible...
	// ...mark as seen and go to "next" message otherwise:
	if (![self scrollMessageTextViewPageDown])
	{
		[[self selectedMessage] addFlags:OPSeenStatus];
		
		GIMessage *nextMessage = [self nextMessage];
		
		if (nextMessage)
		{
			[self setSelectedMessage:nextMessage];
		}
		else
		{
			NSBeep();
		}
	}
}

/*" Removes selected threads from all groups and puts it into trash group "*/
- (IBAction)moveSelectionToTrash:(id)sender
{
	NSIndexSet *selectionIndexes = [threadsController selectionIndexes];
	NSArray *selectedThreads = [threadsController selectedObjects];
	
	// select the thread before (if possible):
	int newSelectionIndex = [selectionIndexes firstIndex] - 1;
	
	if (newSelectionIndex >= 0) 
	{
		[threadsController setSelectionIndex:newSelectionIndex];
	}

	[self threadSelectionDidChange];

    NSEnumerator *enumerator = [selectedThreads objectEnumerator];
    GIThread *thread;
	GIMessageGroup *trash = [GIMessageGroup trashMessageGroup];
        
    while (thread = [enumerator nextObject]) 
	{
		[GIMessageBase addTrashThread:thread];
		NSEnumerator *groupsEnumerator = [[thread valueForKey:@"groups"] objectEnumerator];
		GIMessageGroup *aGroup;
		
		while (aGroup = [groupsEnumerator nextObject])
		{
			if (aGroup != trash)
			{
				[aGroup removeValue:thread forKey:@"threadsByDate"];
			}
		}
    }
    
	[NSApp saveAction:self];
}

- (void)placeSelectedTextOnQuotePasteboard
{
    NSArray *types = [messageTextView writablePasteboardTypes];
    NSPasteboard *quotePasteboard = [NSPasteboard pasteboardWithName:@"QuotePasteboard"];
    
    [quotePasteboard declareTypes:types owner:nil];
    [messageTextView writeSelectionToPasteboard:quotePasteboard types:types];
}

- (GIProfile *)profileForMessage:(GIMessage *)aMessage
/*" Return the profile to use for email replies. Tries first to guess a profile based on the replied email. If no matching profile can be found, the group default profile is chosen. May return nil in case of no group default and no match present. "*/
{
    GIProfile *result;
    
    result = [GIProfile guessedProfileForReplyingToMessage:[aMessage internetMessage]];
    
    if (!result)
    {
        result = [self defaultProfile];
    }
    
    return result;
}

- (IBAction)newMessage:(id)sender
{
    [[[GIMessageEditorController alloc] initNewMessageWithProfile:[self defaultProfile]] autorelease];
}

- (IBAction)forward:(id)sender
{
    GIMessage *message = [self selectedMessage];
	
    [[[GIMessageEditorController alloc] initForward:message profile:[self profileForMessage:message]] autorelease];
}

- (IBAction)replyAll:(id)sender
{
    GIMessage *message = [self selectedMessage];
    
    [self placeSelectedTextOnQuotePasteboard];
    
    [[[GIMessageEditorController alloc] initReplyTo:message all:YES profile:[self profileForMessage:message]] autorelease];
}

- (IBAction)followup:(id)sender
{
    GIMessage *message = [self selectedMessage];
    
    [self placeSelectedTextOnQuotePasteboard];
    
    [[[GIMessageEditorController alloc] initFollowupTo:message profile:[self defaultProfile]] autorelease];
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
        [self replyAll:sender];
    }
}

- (NSArray *)selectedMessages
{
	if ([[self window] firstResponder] == threadsTableView)
	{
		NSMutableArray *result = [NSMutableArray array];
		NSEnumerator *enumerator = [[threadsController selectedObjects] objectEnumerator];
		GIThread *thread;
		
		while (thread = [enumerator nextObject])
		{
			NSArray *messages = [thread valueForKey:@"messages"];
			
			if (messages)
			{
				[result addObjectsFromArray:messages];
			}
		}
		
		return result;
	}
	else
	{
		return [messagesController selectedObjects];
	}
}

- (BOOL)isAnySelectedItemNotHavingMessageflag:(NSString *)attributeName allSelectedMessages:(NSArray **)allMessages
{
    (*allMessages) = [self selectedMessages];
    NSEnumerator *enumerator = [(*allMessages) objectEnumerator];
    GIMessage *message;
    
    while (message = [enumerator nextObject]) 
    {
        if (![[message valueForKey:attributeName] boolValue]) return YES;
    }
    
    return NO;
}

- (void)toggleFlag:(NSString *)attributeName
{
    NSParameterAssert(attributeName != nil);
    
    NSArray *selectedMessages;
    BOOL set = [self isAnySelectedItemNotHavingMessageflag:attributeName 
                                       allSelectedMessages:&selectedMessages];
    NSEnumerator *enumerator = [selectedMessages objectEnumerator];
    GIMessage *message;
    NSNumber *setNumber = [NSNumber numberWithBool:set];
    
    while (message = [enumerator nextObject]) 
    {
        [message setValue:setNumber forKey:attributeName];
    }
    
    [GIApp saveAction:self];
	[threadsController rearrangeObjects];
}

- (IBAction)toggleReadFlag:(id)sender
{
    [self toggleFlag:@"isSeen"];
}

- (IBAction)toggleJunkFlag:(id)sender
{
    [self toggleFlag:@"isJunk"];
}

- (BOOL)validateSelector:(SEL)aSelector
{
	if (aSelector == @selector(moveSelectionToTrash:)) 
	{
        return [[threadsController selectedObjects] count] > 0;
    }
	else if (aSelector == @selector(replyDefault:) || aSelector == @selector(replyAll:) || aSelector == @selector(forward:))
	{
		return [self selectedMessage] != nil;
	}
	else if (aSelector == @selector(followup:))
	{
		return [[self selectedMessage] isUsenetMessage];
	}
	else if ((aSelector == @selector(toggleReadFlag:)) || (aSelector == @selector(toggleJunkFlag:))) 
	{
        return ([self selectedMessage] != nil) || ([threadsController selectionIndex] >= 0);
    } 
	else if (aSelector == @selector(newMessage:))
	{
		return YES;
	}
	
	return NO;
}

- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem
{
	return [self validateSelector:[menuItem action]];
}

@end

#import "NSAttributedString+MessageUtils.h"

@implementation GIThreadsController (TextViewDelegate)

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
    
    [[NSWorkspace sharedWorkspace] openFile:filename];
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
		mouseLocation = [view convertPoint:mouseLocation toView:nil];
		
		rect = NSMakeRect(mouseLocation.x, mouseLocation.y, 1, 1);
		[view dragFile:filename fromRect:rect slideBack:YES event:event];
	}
}

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)flag
{
    return NSDragOperationCopy | NSDragOperationMove;
}

- (BOOL)ignoreModifierKeysWhileDragging
{
    return NO;
}

@end

@implementation GIThreadsController (DragAndDrop)

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard 
{
	if (tv == threadsTableView)
	{
		NSArray *selectedThreads = [threadsController selectedObjects];
		
		if ([selectedThreads count])
		{
			// Copy the row numbers to the pasteboard.
			[pboard declareTypes:[NSArray arrayWithObject:@"GinkoThreads"] owner:self];
			
			NSEnumerator *enumerator = [selectedThreads objectEnumerator];
			NSMutableArray *pbItems = [NSMutableArray arrayWithCapacity:[selectedThreads count]];
			GIThread *thread;
			
			while (thread = [enumerator nextObject])
			{
				NSNumber *oid = [NSNumber numberWithUnsignedLongLong:[thread oid]];
				[pbItems addObject:oid];
			}
			
			[pboard setPropertyList:pbItems forType:@"GinkoThreads"];
			return YES;
		}
	}
	return NO;	
}

- (NSDragOperation)tableView:(NSTableView *)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op 
{
    if (tv == threadsTableView) 
    {
		if ([self group])
		{
			if ([info draggingSource] != threadsTableView) // don't let drop on itself
			{
				NSArray *items = [[info draggingPasteboard] propertyListForType:@"GinkoThreads"];
				
				if ([items count] > 0) 
				{
					[tv setDropRow:-1 dropOperation:NSTableViewDropOn]; 
					return op;
				}
			}
		}
    }
    
    return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)tv acceptDrop:(id <NSDraggingInfo>)info 
			  row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
    if (tv == threadsTableView)
    {
        // move threads from source group to destination group:
        NSArray *threadOids = [[info draggingPasteboard] propertyListForType:@"GinkoThreads"];
        GIMessageGroup *sourceGroup = [(GIThreadsController *)[[info draggingSource] delegate] group];
        GIMessageGroup *destinationGroup = [self group];
        
		if (sourceGroup)
		{
			[GIMessageGroup moveThreadsWithOids:threadOids fromGroup:sourceGroup toGroup:destinationGroup];
		}
		else
		{
			NSEnumerator *enumerator = [threadOids objectEnumerator];
			NSNumber *threadOid;
			OPPersistentObjectContext *context = [OPPersistentObjectContext defaultContext];
			while (threadOid = [enumerator nextObject])
			{
				GIThread *thread = [context objectForOid:[threadOid unsignedLongLongValue] ofClass:[GIThread class]];
				
				// add thread to destination group:
				[thread addValue:thread forKey:@"threadsByDate"];
			}
		}
        
//        // select all in dragging source:
//        NSOutlineView *sourceView = [info draggingSource];        
//        [sourceView selectRow:[sourceView selectedRow] byExtendingSelection:NO];
        
        [NSApp saveAction:self];
		
		return YES;
    }
    
    return NO;
}

@end