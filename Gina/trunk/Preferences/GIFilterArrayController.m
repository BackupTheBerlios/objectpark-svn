//
//  GIFilterArrayController.m
//  Gina
//
//  Created by Axel Katerbau on 14.12.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import "GIFilterArrayController.h"
#define GIFILTERPREFTYPE @"GinkoFilterPrefType"

@implementation GIFilterArrayController

- (void)awakeFromNib
{
    // Register to grok GIFILTERPREFTYPE drags
    [tableView registerForDraggedTypes:[NSArray arrayWithObject:GIFILTERPREFTYPE]];
	
	[super awakeFromNib];
}

//- (id)newObject
//{
//	id result = [super newObject];
////	[result setObject:[NSPredicate predicateWithFormat:@"name CONTAINS \"Dirky\""] forKey:@"predicate"];
//	return result;
//}

- (IBAction)clone:(id)sender
{
	NSMutableArray *newObjects = [NSMutableArray array];
	
	for (id object in [self selectedObjects])
	{
		NSString *name = [[object valueForKey:@"name"] stringByAppendingString:NSLocalizedString(@" copy", @"postfix for cloned filter entries")];
		id clone = [[object mutableCopy] autorelease];
		[clone setValue:name forKey:@"name"];
		
		[newObjects addObject:clone];
	}
	
	if ([newObjects count])
	{
		[self insertObjects:newObjects atArrangedObjectIndexes:[self selectionIndexes]];
		//[self performSelector:@selector(addObjects:) withObject:newObjects afterDelay:0.0];
	}
}

- (void)moveObjectAtArrangedObjectIndex:(NSUInteger)oldIndex toArrangedObjectIndex:(NSUInteger)newIndex
{
    int diff = (oldIndex < newIndex) ? -1 : 0;
    
	id object = [[[self arrangedObjects] objectAtIndex:oldIndex] retain];
	
	[self removeObjectAtArrangedObjectIndex:oldIndex];
	[self insertObject:object atArrangedObjectIndex:newIndex + diff];
	
    [object release];
}

@end

@implementation GIFilterArrayController (DragNDrop)

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
    NSArray *rows = [[info draggingPasteboard] propertyListForType:GIFILTERPREFTYPE];
    
    NSAssert([rows count] == 1, @"More than one filter per drag is not supported");
    
    NSUInteger oldIndex = [[rows objectAtIndex:0] unsignedIntValue];
    [self moveObjectAtArrangedObjectIndex:oldIndex toArrangedObjectIndex:row];
    
    return YES;
}

- (NSDragOperation)tableView:(NSTableView *)aTableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)operation
{
    [tableView setDropRow:row dropOperation:NSTableViewDropAbove];
    return [info draggingSourceOperationMask];
}

- (BOOL)tableView:(NSTableView *)aTableView writeRows:(NSArray *)rows toPasteboard:(NSPasteboard *)pboard
{
    [pboard declareTypes:[NSArray arrayWithObject:GIFILTERPREFTYPE] owner:self];
    [pboard setPropertyList:rows forType:GIFILTERPREFTYPE];
    
    return YES;
}

@end
