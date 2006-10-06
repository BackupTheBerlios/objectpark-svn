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

@implementation GIThreadsController

- (id)initWithThreads:(NSArray *)someThreads
{
	if (self = [self initWithWindowNibName:@"Threads"])
	{
		[self setThreads:someThreads];
		[self window]; // making sure the bindings are active
	}
	
	return [self retain];
}

- (void)dealloc
{
	[threads release];
	[viewedMessage release];
	[super dealloc];
}

- (void)windowDidLoad
{
	// set up date formatters:
	[[threadDateColumn dataCell] setFormatter:dateFormatter()];
	[[messageDateColumn dataCell] setFormatter:dateFormatter()];
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
#warning bind to user defaults
	BOOL selectFirstUnreadMessageInThread = YES;
	
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
		if (!message) // select first if all are read
		{
			[messagesController setSelectedObjects:[NSArray arrayWithObject:[messages firstObject]]];
		}
	}
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	[self resetMessageTextView];
	
	if ([[aNotification object] tag] == 0) // the thread table view
	{
		[self threadSelectionDidChange];
	}
}

/*" Selects the thread threadToSelect in the receiver and makes sure the selection is visible. "*/
- (void)selectThread:(GIThread *)threadToSelect
{
	[threadsController setSelectedObjects:[NSArray arrayWithObject:threadToSelect]];
	[self threadSelectionDidChange];
}

- (void)setThreads:(NSArray *)someThreads
{
	if (someThreads != threads)
	{
		[someThreads retain];
		[threads release];
		threads = [someThreads retain];
	}
}

- (NSArray *)threads
{
	return threads;
}

- (void)setViewedMessage:(GIMessage *)aMessage
{
	[aMessage retain];
	[viewedMessage release];
	viewedMessage = aMessage;
}

- (void)viewSelectedMessage
{
	NSArray *selectedMessages = [messagesController selectedObjects];
	
	if ([selectedMessages count] == 1)
	{
		[self setViewedMessage:[selectedMessages lastObject]];
	}
	else
	{
		[self setViewedMessage:nil];
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
