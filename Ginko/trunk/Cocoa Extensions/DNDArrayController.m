//
//  DNDArrayController.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 19.10.06.
//  Copyright 2006 Objectpark Group. All rights reserved.
//

#import "DNDArrayController.h"


@implementation DNDArrayController

- (void)setDndDelegate:(id)aDelegate
{
	dndDelegate = aDelegate;
}

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard 
{
	return [dndDelegate tableView:tv writeRowsWithIndexes:rowIndexes toPasteboard:pboard];
}

- (NSDragOperation)tableView:(NSTableView*)tv
				validateDrop:(id <NSDraggingInfo>)info
				 proposedRow:(int)row
	   proposedDropOperation:(NSTableViewDropOperation)op
{
	return [dndDelegate tableView:tv
					 validateDrop:info
					  proposedRow:row
			proposedDropOperation:op];
}

- (BOOL)tableView:(NSTableView*)tv
	   acceptDrop:(id <NSDraggingInfo>)info
			  row:(int)row
	dropOperation:(NSTableViewDropOperation)op
{
	return [dndDelegate tableView:tv
					   acceptDrop:info
							  row:row
					dropOperation:op];
}

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)flag
{
    return NSDragOperationCopy | NSDragOperationMove;
}

- (BOOL)ignoreModifierKeysWhileDragging
{
    return NO;
}

- (id)group
{
	return [dndDelegate group];
}

@end
