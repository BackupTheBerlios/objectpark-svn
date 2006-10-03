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
}

- (NSArray *)threadMessages
{
	GIThread *thread = [self selectedThread];
	return [thread valueForKey:@"messages"];
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

- (int)infoPanelTableViewFontSize
{
	return 10;
}

- (int)infoPanelTableViewRowHeight
{
	return 12;
}

@end
