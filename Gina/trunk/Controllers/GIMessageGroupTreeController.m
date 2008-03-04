//
//  GIMessageGroupTreeController.m
//  Gina
//
//  Created by Axel Katerbau on 15.10.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import "GIMessageGroupTreeController.h"
#import "GIMessageGroup.h"
#import "GIMessageGroupCell.h"

#define SelectedMessageGroup @"SelectedMessageGroup"

@implementation GIMessageGroupTreeController

#warning drag & drop is missing
- (void)awakeFromNib
{
	[super awakeFromNib];
	
    // register for drag and drop
    //[outlineView registerForDraggedTypes:[NSArray arrayWithObjects:NSURLPboardType, nil]];
	
	[[outlineView tableColumnWithIdentifier:@"name"] setDataCell:[[[GIMessageGroupCell alloc] init] autorelease]];
	[outlineView sizeLastColumnToFit];
	
	[outlineView setColumnAutoresizingStyle:NSTableViewSequentialColumnAutoresizingStyle];
	
	[self addObserver:self forKeyPath:@"selectionIndexPaths" options:0 context:NULL];
	// [[self class] setKeys: [NSArray arrayWithObject: @"selectionIndexes"] triggerChangeNotificationsForDependentKey: @"selectedObject"]; // not working, see http://www.cocoabuilder.com/archive/message/cocoa/2004/10/1/118614

}

- (void)setContent:(id)content
{
	[super setContent:content];
	
	// restore remembered selection:
	NSArray *indexPathComponents = [[NSUserDefaults standardUserDefaults] objectForKey:SelectedMessageGroup];
	if ([indexPathComponents count])
	{
		NSUInteger *indexes = malloc([indexPathComponents count] * sizeof(NSUInteger));
		
		for (int i = 0; i < [indexPathComponents count]; i++)
		{
			indexes[i] = [[indexPathComponents objectAtIndex:i] unsignedIntValue];
		}
		
		NSIndexPath *indexPath = [NSIndexPath indexPathWithIndexes:indexes length:[indexPathComponents count]];
		
		free(indexes);
		
		[self setSelectionIndexPath:indexPath];
	}
}

- (void)dealloc
{
	[self removeObserver:self forKeyPath:@"selectionIndexPaths"];
	[super dealloc];	
}

// See http://www.cocoabuilder.com/archive/message/cocoa/2004/10/1/118614

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([@"selectionIndexPaths" isEqualToString:keyPath]) {
		[self willChangeValueForKey:@"selectedObject"]; // depedent keys do not seem to work
		[self didChangeValueForKey:@"selectedObject"]; // depedent keys do not seem to work
	}
	[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

/*" Returns the selected object, if there is exactly one. "*/
- (id)selectedObject
{
	NSArray *selected = [self selectedObjects];
	return [selected count] == 1 ? [selected objectAtIndex:0] : nil;
}

- (NSIndexPath*) findObject: (id) object inTreeArray: (NSArray*) array indexPath: (NSIndexPath*) path
{
	NSUInteger index = 0;
	for (id element in array) {
		NSIndexPath* newIndexPath = path ? [path indexPathByAddingIndex: index] : [NSIndexPath indexPathWithIndex: index];
		if (element == object) return newIndexPath;
		NSArray* kids = [element children];
		if (newIndexPath = [self findObject: object inTreeArray: kids indexPath: newIndexPath]) {
			return newIndexPath;
		}
		path = newIndexPath;
		index+=1;
	}
	return nil;
}

- (void) setSelectedObject: (id) object
{
	if (object) {
		id root = [self arrangedObjects];
		NSIndexPath* indexPath = [self findObject: object inTreeArray: [root childNodes] indexPath: nil];
		[self setSelectionIndexPath: indexPath];
	}
}

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{	
	if ([[item representedObject] isKindOfClass:[GIMessageGroup class]]) 
	{
		[cell setImage:[NSImage imageNamed:@"OtherMailbox"]];
	} 
	else 
	{
		[cell setImage:[NSImage imageNamed:@"Folder"]];
	}
	
	if ([cell isKindOfClass:[GIMessageGroupCell class]]) 
	{
		[cell setHierarchyItem:item];
	}
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	NSLog(@"- outlineView setObjectValue %@", object);
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
	NSIndexPath *indexPath = [self selectionIndexPath];
	NSMutableArray *indexPathComponents = [NSMutableArray arrayWithCapacity:[indexPath length]];
	
	for (int i = 0; i < [indexPath length]; i++)
	{
		[indexPathComponents addObject:[NSNumber numberWithUnsignedInt:[indexPath indexAtPosition:i]]];
	}
	
	[[NSUserDefaults standardUserDefaults] setObject:indexPathComponents forKey:SelectedMessageGroup];
}

@end
