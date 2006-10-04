//
//  GIThreadListController+ThreadInfoPanel.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 03.10.06.
//  Copyright 2006 Objectpark Group. All rights reserved.
//

#import "GIThreadListController+ThreadInfoPanel.h"


@implementation GIThreadListController (ThreadInfoPanel)

+ (void)initialize
{
	[self setKeys:[NSArray arrayWithObjects:@"selectedThread", nil]
    triggerChangeNotificationsForDependentKey:@"threadParticipants"];
	
	[self setKeys:[NSArray arrayWithObjects:@"selectedThread", nil]
    triggerChangeNotificationsForDependentKey:@"threadMessages"];

	[self setKeys:[NSArray arrayWithObjects:@"selectedThread", nil]
    triggerChangeNotificationsForDependentKey:@"threadMessagesTitle"];

	[self setKeys:[NSArray arrayWithObjects:@"selectedThread", nil]
    triggerChangeNotificationsForDependentKey:@"threadParticipantsTitle"];

	[self setKeys:[NSArray arrayWithObjects:@"selectedThread", nil]
    triggerChangeNotificationsForDependentKey:@"threadTimeSpanDescription"];
}

- (NSArray *)threadMessages
{
	GIThread *thread = [self selectedThread];
	return [thread valueForKey:@"messages"];
}

- (NSString *)threadMessagesTitle
{
	int count = [[self threadMessages] count];
	
	NSString *format = count == 1 ? NSLocalizedString(@"%d Message:" , @"thread info 'thread messages' title") : NSLocalizedString(@"%d Messages:" , @"thread info 'thread messages' title");
	
	return [NSString stringWithFormat:format, count];
}

- (NSArray *)threadParticipants
{
	NSCountedSet *senderNames = [NSCountedSet set];
	
	NSEnumerator *enumerator = [[self threadMessages] objectEnumerator];
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

- (NSString *)threadParticipantsTitle
{
	int count = [[self threadParticipants] count];
	
	NSString *format = count == 1 ? NSLocalizedString(@"%d Participant:" , @"thread info 'thread participants' title") : NSLocalizedString(@"%d Participants:" , @"thread info 'thread participants' title");
	
	return [NSString stringWithFormat:format, count];
}

- (int)infoPanelTableViewFontSize
{
	return 10;
}

- (int)infoPanelTableViewRowHeight
{
	return 12;
}

- (NSString *)threadTimeSpanDescription
{
	NSArray *messages = [self threadMessages];
	
	if ([messages count] == 0) return @"";
	
	GIMessage *firstMessage = [messages objectAtIndex:0];
	GIMessage *lastMessage = [messages lastObject];
	
	if (firstMessage == lastMessage)
	{
		return [infoPanelDateFormatter stringForObjectValue:[firstMessage valueForKey:@"date"]];
	}
	else
	{
		return [NSString stringWithFormat:@"%@ - %@", [infoPanelDateFormatter stringForObjectValue:[firstMessage valueForKey:@"date"]], [infoPanelDateFormatter stringForObjectValue:[lastMessage valueForKey:@"date"]]];
	}
}

@end
