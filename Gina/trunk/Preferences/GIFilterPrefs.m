//
//  GIFilterPrefs.m
//  Gina
//
//  Created by Axel Katerbau on 13.12.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import "GIFilterPrefs.h"
#import <Foundation/NSDebug.h>

@implementation GIFilterPrefs

static NSMutableArray *filters = nil;

- (NSMutableArray *)filters
{	
	if (!filters)
	{
		filters = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Filters"] mutableCopy];
		if (!filters)
		{
			filters = [[NSMutableArray alloc] init];
		}
	}
	
	return filters;
}

- (void)setFilters:(NSMutableArray *)someFilters
{
	[filters autorelease];
	filters = [someFilters retain];
	[[NSUserDefaults standardUserDefaults] setObject:filters forKey:@"Filters"];
}

- (void)ruleEditorRowsDidChange:(NSNotification *)notification
{
}

- (NSIndexSet *)selectedFilterIndexes
{
	return selectedFilterIndexes;
}

- (void)setSelectedFilterIndexes:(NSIndexSet *)anIndexSet
{
	selectedFilterIndexes = anIndexSet;
	
	[self willChangeValueForKey:@"selectedFilterPredicate"];
	[self didChangeValueForKey:@"selectedFilterPredicate"];
	[self willChangeValueForKey:@"selectedFilterMessageGroup"];
	[self didChangeValueForKey:@"selectedFilterMessageGroup"];
	
	if ([predicateEditor numberOfRows] == 0)
	{
		[predicateEditor addRow:self];
	}		
}

- (NSPredicate *)selectedFilterPredicate
{
	id currentFilter = [[filterArrayController selectedObjects] lastObject];
	NSString *predicateFormat = [currentFilter valueForKey:@"predicateFormat"];
	NSPredicate *predicate = [NSPredicate predicateWithFormat:predicateFormat];
	
	return predicate;
}

- (void)setSelectedFilterPredicate:(NSPredicate *)aPredicate
{
	id currentFilter = [[filterArrayController selectedObjects] lastObject];
	NSString *predicateFormat = [aPredicate predicateFormat];
	[currentFilter setValue:predicateFormat forKey:@"predicateFormat"];
	
	if (NSDebugEnabled) NSLog(@"predicate = %@", predicateFormat);
	
	[[NSUserDefaults standardUserDefaults] setObject:filters forKey:@"Filters"];
}

- (NSArray *)messageGroupsByTree
{
	return [NSArray arrayWithObjects:
			[NSDictionary dictionaryWithObjectsAndKeys:
			 @"A Group", @"name",
			 @"Private/A Group", @"treePathDescription",
			 @"OPMessageGroup-fake1", @"objectURLString",
			 nil, nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
			 @"Another Group", @"name",
			 @"Business/Another Group", @"treePathDescription",
			 @"OPMessageGroup-fake2", @"objectURLString",
			 nil, nil]
			, nil];
}

- (id)selectedFilterMessageGroup
{
	id currentFilter = [[filterArrayController selectedObjects] lastObject];
	id objectURLString = [currentFilter valueForKey:@"putInMessageGroupObjectURLString"];
	
	for (id result in [self messageGroupsByTree])
	{
		if ([[result valueForKey:@"objectURLString"] isEqualToString:objectURLString])
		{
			return result;
		}
	}
	
	return nil;
}

- (void)setSelectedFilterMessageGroup:(id)aMessageGroup
{
	id currentFilter = [[filterArrayController selectedObjects] lastObject];
	id objectURLString = [aMessageGroup valueForKey:@"objectURLString"];
	if (!objectURLString) objectURLString = [NSNull null];
	[currentFilter setValue:objectURLString forKey:@"putInMessageGroupObjectURLString"];
	[[NSUserDefaults standardUserDefaults] setObject:filters forKey:@"Filters"];
}

@end
