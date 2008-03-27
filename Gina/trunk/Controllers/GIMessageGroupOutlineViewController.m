//
//  GIMessageGroupOutlineViewController.m
//  Gina
//
//  Created by Axel Katerbau on 07.03.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "GIMessageGroupOutlineViewController.h"
#import "GIMessageGroup.h"
#import "GIMessageGroupCell.h"
#import "OPPersistentObjectContext.h"

@implementation GIMessageGroupOutlineViewController

- (void)awakeFromNib
{
//	[super awakeFromNib];
	
    // register for drag and drop
    //[outlineView registerForDraggedTypes:[NSArray arrayWithObjects:NSURLPboardType, nil]];
	
	[[outlineView tableColumnWithIdentifier:@"name"] setDataCell:[[[GIMessageGroupCell alloc] init] autorelease]];
	[[outlineView tableColumnWithIdentifier:@"unreadMessageCount"] setDataCell:[[[GIMessageGroupCell alloc] init] autorelease]];
	[outlineView sizeLastColumnToFit];
	
	[outlineView setColumnAutoresizingStyle:NSTableViewSequentialColumnAutoresizingStyle];
	
	// Register to grok GinaThreads and GinaHierarchyNodes drags:
    [outlineView registerForDraggedTypes:[NSArray arrayWithObjects:@"GinaThreads", @"GinaHierarchyNodes", nil]];
}

- (NSSet *)keyPathsAffectingDisplayOfItem:(id)item
{
	static NSSet *affectingKeyPaths = nil;
	if (! affectingKeyPaths) 
	{
		affectingKeyPaths = [[NSSet setWithObjects:@"name", @"unreadMessageCount", nil] retain];
	}
	return affectingKeyPaths;
}

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{	
	if ([item isKindOfClass:[GIMessageGroup class]]) 
	{
		[cell setImage:[GIMessageGroup imageForMessageGroup:item]];
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

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	return YES;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	return ![item isKindOfClass:[GIMessageGroup class]];
}

- (void)deleteHierarchyNode:(GIHierarchyNode *)aNode
{
	GIHierarchyNode *parent = [outlineView parentForItem:aNode];
	
	if (!parent) parent = [GIHierarchyNode messageGroupHierarchyRootNode];
	
	[[aNode retain] autorelease];
	[[parent mutableArrayValueForKey:@"children"] removeObject:aNode];
	[aNode delete];
}

@end

@implementation GIMessageGroupOutlineViewController (OPDragNDrop)

/*" Moves a hierarchy node sourceNode to another hierarchy node destinationNode at the given index anIndex. If testOnly is YES, it only checks if the move was legal. Returns YES if the move was successful, NO otherwise. "*/
- (BOOL)moveHierarchyNode:(id)sourceNode toHierarchyNode:(GIHierarchyNode *)destinationNode atIndex:(NSUInteger)anIndex testOnly:(BOOL)testOnly
{
    // find source's hierarchy and index
	GIHierarchyNode *sourceParent = [outlineView parentForItem:sourceNode];
	if (!sourceParent) sourceParent = [GIHierarchyNode messageGroupHierarchyRootNode];
    NSUInteger sourceIndex = [sourceParent.children indexOfObject:sourceNode];
        
    // don't allow folders being moved to subfolders of themselves
    if (![sourceNode isKindOfClass:[GIMessageGroup class]]) 
	{				
        if ([sourceNode isEqual:destinationNode]) return NO;
        if ([GIHierarchyNode findHierarchyNode:destinationNode startingWithHierarchyNode:sourceNode]) {
            return NO;
        }
    }
    
    if (! testOnly) 
	{        
        // is entry's hierarchy equal target hierarchy?
        if (sourceParent == destinationNode) 
		{
            // take care of indexes:
            if (sourceIndex < anIndex) anIndex--;
        }
        
        [sourceNode retain];
        
		NSMutableArray *children = [sourceParent mutableArrayValueForKey:@"children"];
        [children removeObject:sourceNode];
        
        if (anIndex < [destinationNode.children count]) 
		{
            [[destinationNode mutableArrayValueForKey:@"children"] insertObject:sourceNode atIndex:anIndex];
        } 
		else 
		{
            [[destinationNode mutableArrayValueForKey:@"children"] addObject:sourceNode];
        }
        
        [sourceNode release];        
		
		[[OPPersistentObjectContext defaultContext] saveChanges];
    }
    
    return YES;
}

- (BOOL)outlineView:(NSOutlineView *)anOutlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard
{
	NSParameterAssert(anOutlineView == outlineView);
	// ##WARNING works only for single selections. Not for multi selection!
	
	[pboard declareTypes:[NSArray arrayWithObject:@"GinaHierarchyNodes"] owner:self]; 
	
	NSMutableArray *nodeURLStrings = [NSMutableArray array];
	for (GIHierarchyNode *node in items)
	{
		[nodeURLStrings addObject:[node objectURLString]];
	}
	
	[pboard setPropertyList:nodeURLStrings forType:@"GinaHierarchyNodes"];
	
    return YES;
}

- (NSDragOperation)outlineView:(NSOutlineView *)anOutlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(int)index
{
	NSParameterAssert(anOutlineView == outlineView);
	// Message Groups
	NSArray *objectURLStrings = [[info draggingPasteboard] propertyListForType:@"GinaHierarchyNodes"];
	
	if ([objectURLStrings count] == 1) 
	{
		if (index != NSOutlineViewDropOnItemIndex) 
		{
			GIHierarchyNode *sourceNode = [[OPPersistentObjectContext defaultContext] objectWithURLString:[objectURLStrings lastObject]];
			// accept only when not on item:
			if ([self moveHierarchyNode:sourceNode toHierarchyNode:item atIndex:index testOnly:YES])
			{
				[anOutlineView setDropItem:item dropChildIndex:index]; 
				return NSDragOperationMove;
			}
		}
	}
	
	// thread drop:
	
	if ([item isKindOfClass:[GIMessageGroup class]])
	{
		NSArray *threadURLs = [[info draggingPasteboard] propertyListForType:@"GinaThreads"];
		if ([threadURLs count]) 
		{
			if (index == NSOutlineViewDropOnItemIndex) return NSDragOperationMove;
		}
	}
	
	return NSDragOperationNone;
}

- (BOOL)outlineView:(NSOutlineView *)anOutlineView acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(int)index
{
	NSParameterAssert(anOutlineView == outlineView);
    
	// Message Groups list
	if (! item) item = [GIHierarchyNode messageGroupHierarchyRootNode];
	
	NSArray *objectURLStrings = [[info draggingPasteboard] propertyListForType:@"GinaHierarchyNodes"];
	if ([objectURLStrings count] == 1) 
	{		
		GIHierarchyNode *sourceNode = [[OPPersistentObjectContext defaultContext] objectWithURLString:[objectURLStrings lastObject]];

		[self moveHierarchyNode:sourceNode toHierarchyNode:item atIndex:index testOnly:NO];
				
		return YES;
	}
	
	// threads drop:
	if ([item isKindOfClass:[GIMessageGroup class]])
	{
		NSArray *threadURLs = [[info draggingPasteboard] propertyListForType:@"GinaThreads"];
		if ([threadURLs count]) 
		{
#warning assuming the drag began in the same window
			GIMessageGroup *sourceGroup = self.selectedObject;
			NSAssert([sourceGroup isKindOfClass:[GIMessageGroup class]], @"source should be a message group");
			GIMessageGroup *destinationGroup = item;
			
			[GIMessageGroup moveThreadsWithURLs:threadURLs fromGroup:sourceGroup toGroup:destinationGroup];

			return YES;
		}
	}
	
	return NO;
}

@end
