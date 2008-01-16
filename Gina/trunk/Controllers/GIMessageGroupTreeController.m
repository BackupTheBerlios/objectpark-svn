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

@end
