//
//  GIGroupListController.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 24.10.05.
//  Copyright 2005 The Objectpark Group. All rights reserved.
//

#import "GIGroupListController.h"
#import <Foundation/NSDebug.h>
//#import "NSToolbar+OPExtensions.h"
#import "GIMessageEditorController.h"
#import "GIThreadListController.h"
#import "OPCollapsingSplitView.h"
#import "GIUserDefaultsKeys.h"
#import "GIApplication.h"
#import "NSArray+Extensions.h"
#import "GIGroupInspectorController.h"
#import "OPPersistentObject+Extensions.h"
#import "GIMessageGroup.h"
#import "OPJobs.h"
#import "GIOutlineViewWithKeyboardSupport.h"
#import "GIMessageBase.h"
#import "NSString+Extensions.h"
#import "GIApplication.h"
#import "OPImageAndTextCell.h"
#import "GIMessageGroup+Statistics.h"

@implementation GIGroupListController

- (void)awakeFromNib
{    
    [boxesView setTarget:self];
    [boxesView setDoubleAction:@selector(showGroupWindow:)];
    
    // Register to grok GinkoMessages and GinkoMessageboxes drags:
    [boxesView registerForDraggedTypes:[NSArray arrayWithObjects: @"GinkoThreads", @"GinkoMessageboxes", nil]];
    
    [boxesView setAutosaveName:@"boxesView"];
    [boxesView setAutosaveExpandedItems:YES];

    // set cell for first table column
    {
        id cell;
        
        cell = [[[OPImageAndTextCell alloc] init] autorelease];
        [cell setEditable:YES];
        [[boxesView tableColumnWithIdentifier:@"box"] setDataCell:cell];
    }
    
    //[self awakeToolbar];
	
    //lastTopLeftPoint = [window cascadeTopLeftFromPoint:lastTopLeftPoint];
    
    [window makeKeyAndOrderFront:self];    
}

- (id) init
{
    if (self = [super init]) {
        [NSBundle loadNibNamed: @"Boxes" owner: self];
		
        [[NSNotificationCenter defaultCenter] addObserver: self 
												 selector: @selector(groupsChanged:) 
													 name: GIMessageGroupWasAddedNotification 
												   object: nil];
        
        [[NSNotificationCenter defaultCenter] addObserver: self 
												 selector: @selector(groupsChanged:) 
													 name: GIMessageGroupStatisticsDidInvalidateNotification 
												   object: nil];
		
		
		[[NSNotificationCenter defaultCenter] addObserver: self 
												 selector: @selector(jobStarted:) 
													 name: OPJobWillStartNotification 
												   object: nil];
		
		[[NSNotificationCenter defaultCenter] addObserver: self 
												 selector: @selector(jobFinished:) 
													 name: OPJobDidFinishNotification 
												   object: nil];
		
    }
    
	return [self retain]; // self retaining!
}


  
- (GIMessageGroup*) group
/*" Returns the selected message group if one and only one is selected. nil otherwise. "*/
{
	id selectedItem = [boxesView itemAtRow: [boxesView selectedRow]];
	if ([selectedItem isKindOfClass: [NSString class]]) {
		GIMessageGroup* selectedGroup = [[OPPersistentObjectContext defaultContext] objectWithURLString: selectedItem];
		
		if (selectedGroup && [selectedGroup isKindOfClass: [GIMessageGroup class]]) return selectedGroup;
		
	}
	return nil;
}

- (void) groupsChanged: (NSNotification*) aNotification
{
    [boxesView reloadData];
}

- (void) jobStarted: (NSNotification*) aNotification
{
	[globalProgrssIndicator startAnimation: self];
}

- (void) jobFinished: (NSNotification*) aNotification
{
	unsigned jobCount = [[OPJobs runningJobs] count];
	if (jobCount==0) {
		[globalProgrssIndicator stopAnimation: self];
	}
}

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[super dealloc];
}

- (IBAction)showGroupWindow: (id) sender
/*" Shows group in a own window if no such window exists. Otherwise brings up that window to front. "*/
{
    GIMessageGroup *selectedGroup = [self group];
	
    if (selectedGroup) 
    {
        NSWindow *groupWindow = [[GIThreadListController class] windowForGroup:selectedGroup];
        
        if (groupWindow) 
        {
            [groupWindow makeKeyAndOrderFront:self];
        } 
        else 
        {
            GIThreadListController *newController = [[[GIThreadListController alloc] initWithGroup:selectedGroup] autorelease];
            groupWindow = [newController window];
        }
        
        [[groupWindow delegate] showThreads:sender];
    }
}

- (IBAction)showGroupInspector: (id) sender
{
	id selectedGroup = [self group];
	
	if (selectedGroup) {
		[GIGroupInspectorController groupInspectorForGroup:[[OPPersistentObjectContext defaultContext] objectWithURLString:selectedGroup]];
	}
}

- (BOOL) openSelection: (id) sender
{    
    [self showGroupWindow:sender];
	return YES;
}

- (IBAction)rename: (id) sender
/*" Renames the selected item (folder or group). "*/
{
    int lastSelectedRow  = [boxesView selectedRow];
    
    if (lastSelectedRow != -1) 
    {
        int index = [[boxesView tableColumns] indexOfObject:[boxesView tableColumnWithIdentifier:@"box"]];
        [boxesView editColumn:index row:lastSelectedRow withEvent:nil select:YES];
    }
}

- (IBAction) delete: (id) sender
{
	id item = [[boxesView selectedItems] lastObject];
    if ([item isKindOfClass: [NSArray class]]) {
        if ([item count] == 0) {
            [GIMessageGroup removeHierarchyNode: item];
            [GIMessageGroup saveHierarchy];
        } else {
            NSBeep();
            NSLog(@"Unable to remove folder containing groups.");
        }
    } else {
		GIMessageGroup* selectedGroup = [self group];
        if ([[selectedGroup valueForKey: @"threadsByDate"] count] == 0) {
            [GIMessageGroup removeHierarchyNode: item];
            // Delete the group object:
            [selectedGroup delete];
            [GIMessageGroup saveHierarchy];
            
        } else {
            NSBeep();
            NSLog(@"Unable to remove group containing threads.");
        }
		[GIMessageGroup removeHierarchyNode: item];
    } 
}


- (IBAction) exportGroup: (id) sender
{
    GIMessageGroup *group = [self group];
    
    NSLog(@"MBox export for group %@ triggered", group);
    
    if (group)
    {
        NSSavePanel *panel = [NSSavePanel savePanel];
        [panel setTitle:[NSString stringWithFormat:@"Exporting messagebox '%@'", [group valueForKey:@"name"]]];
        [panel setPrompt:@"Export"];
        [panel setNameFieldLabel:@"Export to:"];
        
        if ([panel runModalForDirectory:nil file:[NSString stringWithFormat:@"%@.mbox", [group valueForKey:@"name"]]] == NSFileHandlingPanelCancelButton)
            return;
            
        [OPJobs scheduleJobWithName:@"Mbox export" target:group selector:@selector(exportAsMboxFileWithPath:) argument:[panel filename] synchronizedObject:nil /*group*/];
    }
    else
        NSBeep();
}


- (IBAction) addFolder: (id) sender
{
    int selectedRow = [boxesView selectedRow];
    [boxesView setAutosaveName: nil];
    [GIMessageGroup addNewHierarchyNodeAfterEntry: [boxesView itemAtRow: selectedRow]];
    [boxesView reloadData];
    [boxesView setAutosaveName: @"boxesView"];
    
    [boxesView selectRow: selectedRow + 1 byExtendingSelection: NO];
    [self rename: self];
}

- (IBAction) addMessageGroup: (id) sender
{
    int selectedRow = [boxesView selectedRow];
    id item = [boxesView itemAtRow: selectedRow];
	
    NSMutableArray* node = item;
    int index; // insertion index under node
    
    if ([boxesView isExpandable: item]) {
		// Expand any selected folder:
        index = 0;
        [boxesView expandItem: item];
    } else {
        node = [GIMessageGroup findHierarchyNodeForEntry: item 
							   startingWithHierarchyNode: [GIMessageGroup hierarchyRootNode]];
        
        if (node) {
            index = [node indexOfObject: item]; // +1 correction already in!
        } else {
            node = [GIMessageGroup hierarchyRootNode];
            index = 0;
        }
    }
    
    GIMessageGroup* newGroup = [GIMessageGroup newMessageGroupWithName: nil atHierarchyNode: node atIndex: index];
    
    [boxesView reloadData];
    
    [boxesView setAutosaveName: @"boxesView"];
    [boxesView selectRow: [boxesView rowForItem: newGroup] byExtendingSelection: NO];
    [self rename: self];
	[GIApp saveAction: nil]; // commit new database entry
}

- (IBAction) removeFolderMessageGroup: (id) sender
{
    NSLog(@"-removeFolderMessageGroup: needs to be implemented");
}

@end

@implementation GIGroupListController (OutlineViewDataSource)

/*
- (void) outlineViewSelectionDidChange: (NSNotification*) notification
{
    if ([notification object] == boxesView) {
        id item = [boxesView itemAtRow: [boxesView selectedRow]];
        
        if (! [item isKindOfClass: [NSArray class]]) {
            [self setGroup: [[OPPersistentObjectContext defaultContext] objectWithURLString: item]];
        }
    }
}
*/

- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	// boxes list
	if (! item) return [[GIMessageGroup hierarchyRootNode] count] - 1;
	else if ([item isKindOfClass:[NSMutableArray class]]) return [item count] - 1;

    return 0;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	return [item isKindOfClass:[NSMutableArray class]];
}

- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item
{
	if (!item) item = [GIMessageGroup hierarchyRootNode];
	return [item objectAtIndex:index + 1];
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{    
    if ([[tableColumn identifier] isEqualToString:@"box"]) 
    {
        if ([item isKindOfClass:[NSMutableArray class]]) 
        {
            return [[item objectAtIndex:0] valueForKey:@"name"];
        } 
        else if (item) 
        {
            GIMessageGroup *group = [OPPersistentObjectContext objectWithURLString:item];
            return [group valueForKey:@"name"];
        }
    }
    
    if ([[tableColumn identifier] isEqualToString:@"info"]) 
    {
        if (![item isKindOfClass:[NSMutableArray class]]) 
        {
            GIMessageGroup *group = [OPPersistentObjectContext objectWithURLString:item];
            //NSMutableArray *threadURIs = [NSMutableArray array];
            //NSCalendarDate *date = [[NSCalendarDate date] dateByAddingYears:0 months:0 days:-1 hours:0 minutes:0 seconds:0];
            
            return [group unreadMessageCount];
            /*
             [g fetchThreadURIs:&threadURIs
                 trivialThreads: NULL
                      newerThan: [date timeIntervalSinceReferenceDate]
                    withSubject: nil
                         author: nil
          sortedByDateAscending: YES];
             return [NSNumber numberWithInt: [threadURIs count]];
             */
        }
    }
    return @"";
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *) tableColumn byItem:(id)item
{
    if ([item isKindOfClass:[NSMutableArray class]]) // folder:
    {
        [[item objectAtIndex:0] setObject:object forKey:@"name"];
        [GIMessageGroup saveHierarchy];
        //[outlineView selectRow: [outlineView rowForItem:item]+1 byExtendingSelection: NO];
        //[[outlineView window] endEditingFor:outlineView];
    } 
    else // message group:
    {
        GIMessageGroup *itemGroup = [[OPPersistentObjectContext defaultContext] objectWithURLString:item];
        [itemGroup setValue:object forKey:@"name"];
        [NSApp saveAction:self];
    }
}

- (id)outlineView:(NSOutlineView *)outlineView itemForPersistentObject:(id)object
{
	return [GIMessageGroup hierarchyNodeForUid:object];
}

- (id)outlineView:(NSOutlineView *)outlineView persistentObjectForItem:(id)item
{
	if ([item isKindOfClass:[NSMutableArray class]]) 
    {
		return [[item objectAtIndex:0] objectForKey:@"uid"];
	}
    
    return nil;
}

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    if ([[tableColumn identifier] isEqualToString:@"box"])
    {
        if (![item isKindOfClass:[NSMutableArray class]])
        {
            NSImage *image = [GIMessageGroup imageForMessageGroup:[OPPersistentObjectContext objectWithURLString:item]];
            
            [cell setImage:image];
        }
        else [cell setImage:[NSImage imageNamed:@"Folder"]];
    }
}

@end

@implementation GIGroupListController (DragNDrop)

- (BOOL)outlineView:(NSOutlineView *)anOutlineView acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(int)index
{
    if (anOutlineView == boxesView) 
    {
		// Message Groups list
        if (! item) item = [GIMessageGroup hierarchyRootNode];
        
        NSArray* items = [[info draggingPasteboard] propertyListForType:@"GinkoMessageboxes"];
        if ([items count] == 1) 
        {
			// only single selection supported at this time!
            // Hack (part 1)! Why is this necessary to archive almost 'normal' behavior?
            [boxesView setAutosaveName:nil];
            
            [GIMessageGroup moveEntry:[items lastObject] toHierarchyNode:item atIndex:index testOnly:NO];
            
            [anOutlineView reloadData];
			int row = [anOutlineView rowForItemEqualTo:[items lastObject] startingAtRow:0];
			[anOutlineView selectRow:row byExtendingSelection:NO];
            
            // Hack (part 2)! Why is this necessary to archive almost 'normal' behavior?
            [boxesView setAutosaveName:@"boxesView"];
            
            return YES;
        }
        
        NSArray *threadOids = [[info draggingPasteboard] propertyListForType:@"GinkoThreads"];
		
        if ([threadOids count]) 
        {
            GIMessageGroup *sourceGroup = [(GIThreadListController *)[[info draggingSource] delegate] group];
            GIMessageGroup *destinationGroup = [OPPersistentObjectContext objectWithURLString:item];
            
            [GIMessageGroup moveThreadsWithOids:threadOids fromGroup:sourceGroup toGroup:destinationGroup];
            
            // select all in dragging source:
            NSOutlineView *sourceView = [info draggingSource];        
            [sourceView selectRow:[sourceView selectedRow] byExtendingSelection:NO];
            
            [NSApp saveAction:self];
        }
    }
    return NO;
}

- (NSDragOperation)outlineView:(NSOutlineView *)anOutlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(int)index
{
    if (anOutlineView == boxesView) 
    {
		// Message Groups
        NSArray* items = [[info draggingPasteboard] propertyListForType:@"GinkoMessageboxes"];
        
        if ([items count] == 1) 
		{
            if (index != NSOutlineViewDropOnItemIndex) 
            {
				// accept only when no on item:
                if ([GIMessageGroup moveEntry: [items lastObject] toHierarchyNode: item atIndex: index testOnly: YES]) {
                    [anOutlineView setDropItem:item dropChildIndex:index]; 
                    return NSDragOperationMove;
                }
            }
        }
        
        NSArray* threadURLs = [[info draggingPasteboard] propertyListForType: @"GinkoThreads"];
        if ([threadURLs count]) {
            if (index == NSOutlineViewDropOnItemIndex) return NSDragOperationMove;
        }
        
        return NSDragOperationNone;
    }     
    return NSDragOperationNone;
}

- (BOOL) outlineView: (NSOutlineView*) outlineView writeItems: (NSArray*) items toPasteboard: (NSPasteboard*) pboard
{
    if (outlineView == boxesView) {
        // ##WARNING works only for single selections. Not for multi selection!
        
        [pboard declareTypes: [NSArray arrayWithObject: @"GinkoMessageboxes"] owner: self];    
        [pboard setPropertyList: items forType: @"GinkoMessageboxes"];
    }
    return YES;
}


@end

