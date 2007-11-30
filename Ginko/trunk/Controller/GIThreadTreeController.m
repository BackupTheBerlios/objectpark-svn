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
#import "GIMessageGroup.h"

@implementation GIThreadTreeController

/*
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
*/

+ (NSSet *)keyPathsForValuesAffectingSelectionHasReadMessages
{
	return [NSSet setWithObjects:@"selectedMessages", nil];
}

+ (NSSet *)keyPathsForValuesAffectingSelectionHasUnreadMessages
{
	return [NSSet setWithObjects:@"selectedMessages", nil];
}

+ (NSSet *)keyPathsForValuesAffectingSelectedMessages
{
	return [NSSet setWithObjects:@"selectionIndexPaths", nil];
}

- (void)dealloc
{
	[cachedThreadTreeSelectionIndexPaths release];
	[super dealloc];
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

- (void)rearrangeSelectedNodes
{
	for (NSTreeNode *node in [self selectedNodes])
	{
		[node willChangeValueForKey:@"representedObject"];
		[node didChangeValueForKey:@"representedObject"];
	}
}

- (NSInteger)indexOfThread:(GIThread *)aThread
{
	NSArray *threadNodes = [[self arrangedObjects] childNodes];
	NSUInteger count = [threadNodes count];
	
	for (NSInteger i = 0; i < count; i++)
	{
		GIThread *thread = [[threadNodes objectAtIndex:i] representedObject];
		if (thread == aThread)
		{
			// found thread:
			return i;
		}
	}
	
	return NSNotFound;	
}

- (NSInteger)indexOfMessage:(GIMessage *)aMessage inThreadAtIndex:(NSInteger)threadIndex
{
	if ((!aMessage) || (threadIndex == NSNotFound)) return NSNotFound;
	NSTreeNode *threadNode = [[[self arrangedObjects] childNodes] objectAtIndex:threadIndex];
	NSArray *messageNodes = [threadNode childNodes];
	NSUInteger count = [messageNodes count];
	
	for (NSInteger i = 0; i < count; i++)
	{
		GIMessage *message = [[messageNodes objectAtIndex:i] representedObject];
		if (message == aMessage)
		{
			// found message:
			return i;
		}
	}
	
	return NSNotFound;	
}

- (void)rememberThreadSelectionForGroup:(GIMessageGroup *)group
{
	NSParameterAssert(group != nil);
	
	if ([group isKindOfClass:[GIMessageGroup class]])
	{
		// remember selection:
		NSMutableArray *selectedObjectURLs = [NSMutableArray array];
		
		for (NSTreeNode *node in [self selectedNodes])
		{
			NSString *objectURLString = [[node representedObject] objectURLString];
			
			if (objectURLString)
			{
				[selectedObjectURLs addObject:objectURLString];
			}
		}
		
		NSString *userDefaultsName = [NSString stringWithFormat:@"SelectedObjectsInMessageGroup-%@", [group objectURLString]];
		
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		
		if ([selectedObjectURLs count])
		{
			[defaults setObject:selectedObjectURLs forKey:userDefaultsName];
			NSLog(@"remembered for group %@: %@", [group valueForKey:@"name"], selectedObjectURLs);
			[cachedThreadTreeSelectionIndexPaths release];
			cachedThreadTreeSelectionIndexPaths = [[self selectionIndexPaths] copy];
			cacheSelectionIndexPathsGroupOid = [group oid];
			if (NSDebugEnabled) NSLog(@"cache for group %@, oid %ld is %@", [group valueForKey:@"name"], cacheSelectionIndexPathsGroupOid, cachedThreadTreeSelectionIndexPaths);
		}
		//		else
		//		{
		//			[defaults removeObjectForKey:userDefaultsName];
		//			NSLog(@"forgot for group %@: %@", [group valueForKey:@"name"], selectedObjectURLs);
		//		}
	}
}

- (NSArray *)recallThreadSelectionForGroup:(GIMessageGroup *)group
{
	if ([group isKindOfClass:[GIMessageGroup class]])
	{
		if (cacheSelectionIndexPathsGroupOid == [group oid] && [cachedThreadTreeSelectionIndexPaths count])
		{
			if (NSDebugEnabled) NSLog(@"restored with cache for group %@", [group valueForKey:@"name"]);
			
			return cachedThreadTreeSelectionIndexPaths;
		}
		
		NSString *userDefaultsName = [NSString stringWithFormat:@"SelectedObjectsInMessageGroup-%@", [group objectURLString]];
		
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		NSArray *selectedObjectURLs = [defaults objectForKey:userDefaultsName];
		
		if (NSDebugEnabled) NSLog(@"restored for group %@ with oid=%ld: %@", [group valueForKey:@"name"], [group oid], selectedObjectURLs);
		
		NSMutableArray *result = [NSMutableArray array];
		OPPersistentObjectContext *context = [OPPersistentObjectContext defaultContext];
		for (NSString *urlString in selectedObjectURLs)
		{
			GIThread *thread = nil;
			GIMessage *message = nil;
			
			id object = [context objectWithURLString:urlString resolve:NO];
			if ([object isKindOfClass:[GIThread class]])
			{
				thread = object;
			}
			else if ([object isKindOfClass:[GIMessage class]])
			{
				message = object;
				thread = [message thread];
			}
			else
			{
				NSAssert1(NO, @"not a valid class %@", NSStringFromClass([object class]));
			}
			
			NSUInteger indexes[2];
			
			indexes[0] = [self indexOfThread:thread];
			indexes[1] = [self indexOfMessage:message inThreadAtIndex:indexes[0]];
			
			if (indexes[0] != NSNotFound)
			{
				if (!message)
				{
					[result addObject:[NSIndexPath indexPathWithIndex:indexes[0]]];
				}
				else if (indexes[1] != NSNotFound)
				{
					NSIndexPath *indexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
					[result addObject:indexPath];
				}
			}
		}	
		
		return result;
	}	
	
	return nil;
}

- (void)invalidateThreadSelectionCache
{
	NSLog(@"invalidated threadSelectionCache");
	cacheSelectionIndexPathsGroupOid = 0;
	[cachedThreadTreeSelectionIndexPaths release];
	cachedThreadTreeSelectionIndexPaths = nil;
}

- (void)setContent:(NSArray *)aContent
{
//	[aContent retain];
//	[[self content] release];
//	[self rearrangeObjects];
	[super setContent:nil];
	[super setContent:aContent];
}

@end
