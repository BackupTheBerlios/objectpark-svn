//
//  GIThreadTreeController.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 29.10.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import "GIThreadTreeController.h"
#import "GIThread.h"
#import "GIMessage.h"

@implementation GIThreadTreeController

+ (void)initialize
{
	static BOOL initialized = NO;
	
	if (!initialized)
	{
		[self setKeys:[NSArray arrayWithObjects:@"selectionIndexPaths", nil] triggerChangeNotificationsForDependentKey:@"selectedMessages"];
		[self setKeys:[NSArray arrayWithObjects:@"selectedMessages", nil] triggerChangeNotificationsForDependentKey:@"selectionHasUnreadMessages"];
		[self setKeys:[NSArray arrayWithObjects:@"selectedMessages", nil] triggerChangeNotificationsForDependentKey:@"selectionHasReadMessages"];
		
		initialized = YES;
	}
	
	[super initialize];
}

- (NSArray *)selectedMessages
{
	NSMutableArray *result = [NSMutableArray array];
	
	for (id selectedObject in [self selectedObjects])
	{
		if ([selectedObject isKindOfClass:[GIThread class]])
		{
			[result addObjectsFromArray:[(GIThread *)selectedObject messages]];
		}
		else
		{
			NSAssert([selectedObject isKindOfClass:[GIMessage class]], @"expected a GIMessage object");
			[result addObject:selectedObject];
		}
	}	
	
	return result;
}

- (BOOL)selectionHasUnreadMessages
{
	for (GIMessage *message in [self selectedMessages])
	{
		if (!([message flags] & OPSeenStatus))
		{
			return YES;
		}
	}
	
	return NO;
}

- (BOOL)selectionHasReadMessages
{
	for (GIMessage *message in [self selectedMessages])
	{
		if ([message flags] & OPSeenStatus)
		{
			return YES;
		}
	}
	
	return NO;
}

@end
