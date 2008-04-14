//
//  GIFilterPrefs.m
//  Gina
//
//  Created by Axel Katerbau on 13.12.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import "GIFilterPrefs.h"
#import <Foundation/NSDebug.h>
#import "GIMessageFilter.h"
#import "GIHierarchyNode.h"
#import "GIMessageGroup.h"
#import "OPPersistentObjectContext.h"

@implementation GIFilterPrefs

- (void)didSelect
/*" Invoked when the pref panel was selected. Initialization stuff. "*/
{
    // register for notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hierarchyDidChange:) name:GIHierarchyChangedNotification object:nil];    
}

- (void)willUnselect
/*" Invoked when the pref panel is about to be quit. "*/
{
    // unregister for notifications
    [[NSNotificationCenter defaultCenter] removeObserver:self];    
}

- (void)hierarchyDidChange:(NSNotification *)note
{
	[self willChangeValueForKey:@"messageGroupsByTree"];
	[self didChangeValueForKey:@"messageGroupsByTree"];
}

- (Class) messageFilterClass
{
	return [GIMessageFilter class];
}

- (void)ruleEditorRowsDidChange:(NSNotification *)notification
{
//	[predicateEditor reloadPredicate];
}

- (NSIndexSet *)selectedFilterIndexes
{
	return selectedFilterIndexes;
}

- (void)setSelectedFilterIndexes:(NSIndexSet *)anIndexSet
{
	selectedFilterIndexes = anIndexSet;
	
//	[self willChangeValueForKey:@"selectedFilterPredicate"];
//	[self didChangeValueForKey:@"selectedFilterPredicate"];
	[self willChangeValueForKey:@"selectedFilterMessageGroup"];
	[self didChangeValueForKey:@"selectedFilterMessageGroup"];
	
//	if ([predicateEditor numberOfRows] == 0)
//	{
//		[predicateEditor addRow:self];
//	}		
}

//- (NSPredicate *)selectedFilterPredicate
//{
//	id currentFilter = [[filterArrayController selectedObjects] lastObject];
//	NSString *predicateFormat = [currentFilter valueForKey:@"predicateFormat"];
//	NSPredicate *predicate = nil;
//	
//	@try
//	{
//		predicate = [NSPredicate predicateWithFormat:predicateFormat];
//	}
//	@catch(id localException)
//	{
//		NSLog(@"Exception: %@", localException);
//	}
//	
//	return predicate;
//}
//
//- (void)setSelectedFilterPredicate:(NSPredicate *)aPredicate
//{
//	id currentFilter = [[filterArrayController selectedObjects] lastObject];
//	NSString *predicateFormat = [aPredicate predicateFormat];
//	[currentFilter setValue:predicateFormat forKey:@"predicateFormat"];
//	
//	if (NSDebugEnabled) NSLog(@"predicate = %@", predicateFormat);
//	
//	[[GIMessageFilter class] saveFilters];
//}

- (void)collectGroupPathsAndURLRepresenations:(NSMutableArray *)paths startingAtNode:(GIHierarchyNode *)node prefix:(NSString *)prefix
{
	for (GIHierarchyNode *child in node.children)
	{			
        if ([child isKindOfClass:[GIMessageGroup class]]) 
		{
			if (child.name.length) 
			{
				NSMutableDictionary *entry = [NSMutableDictionary dictionary];
				
				[entry setObject:child.name forKey:@"name"];
				[entry setObject:[prefix stringByAppendingString:child.name] forKey:@"treePathDescription"];
				[entry setObject:[child objectURLString] forKey:@"objectURLString"];
				
				[paths addObject:entry];
			}
        }
		else
		{
			[self collectGroupPathsAndURLRepresenations:paths startingAtNode:child prefix:[prefix stringByAppendingFormat:@"%@/", child.name]];
        } 
    }
}

- (NSArray *)messageGroupsByTree
{
	NSMutableArray *result = [NSMutableArray array];
	
	[self collectGroupPathsAndURLRepresenations:result startingAtNode:[GIHierarchyNode messageGroupHierarchyRootNode] prefix:@""];

	return result;
	
//	return [NSArray arrayWithObjects:
//			[NSDictionary dictionaryWithObjectsAndKeys:
//			 @"A Group", @"name",
//			 @"Private/A Group", @"treePathDescription",
//			 @"OPMessageGroup-fake1", @"objectURLString",
//			 nil, nil],
//			[NSDictionary dictionaryWithObjectsAndKeys:
//			 @"Another Group", @"name",
//			 @"Business/Another Group", @"treePathDescription",
//			 @"OPMessageGroup-fake2", @"objectURLString",
//			 nil, nil]
//			, nil];
}

- (id)selectedFilterMessageGroup
{
	GIMessageFilter *currentFilter = [[filterArrayController selectedObjects] lastObject];
	id objectURLString = [currentFilter.putInMessageGroup objectURLString];
	
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
	GIMessageFilter *currentFilter = [[filterArrayController selectedObjects] lastObject];
	NSString *objectURLString = [aMessageGroup valueForKey:@"objectURLString"];
	if (!objectURLString) objectURLString = @"nothing";
	GIMessageGroup *messageGroup = [[OPPersistentObjectContext defaultContext] objectWithURLString:objectURLString];
	currentFilter.putInMessageGroup = messageGroup;
}

- (IBAction)delete:(id)sender
{
	[filterArrayController remove:sender];
}

@end
