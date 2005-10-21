/*
 $Id: GIFiltersPane.m,v 1.10 2005/05/20 17:33:03 mikesch Exp $
 
 Copyright (c) 2002, 2003 by Axel Katerbau. All rights reserved.
 
 Permission to use, copy, modify and distribute this software and its documentation
 is hereby granted, provided that both the copyright notice and this permission
 notice appear in all copies of the software, derivative works or modified versions,
 and any portions thereof, and that both notices appear in supporting documentation,
 and that credit is given to Axel Katerbau in all documents and publicity
 pertaining to direct or indirect use of this code or its derivatives.
 
 THIS IS EXPERIMENTAL SOFTWARE AND IT IS KNOWN TO HAVE BUGS, SOME OF WHICH MAY HAVE
 SERIOUS CONSEQUENCES. THE COPYRIGHT HOLDER ALLOWS FREE USE OF THIS SOFTWARE IN ITS
 "AS IS" CONDITION. THE COPYRIGHT HOLDER DISCLAIMS ANY LIABILITY OF ANY KIND FOR ANY
 DAMAGES WHATSOEVER RESULTING DIRECTLY OR INDIRECTLY FROM THE USE OF THIS SOFTWARE
 OR OF ANY DERIVATIVE WORK.
 
 Further information can be found on the project's web pages
 at http://www.objectpark.org/Ginko.html
 */

#import "GIMessage.h"
#import "GIMessageGroup.h"
#import "GIFiltersPane.h"
#import "GIMessageFilter.h"
#import "GIMessageFilterExpression.h"
#import "GIMessageFilterAction.h"

#define GIFILTERPREFTYPE @"GinkoFilterPrefType"

@interface GIFiltersPane (PrivateAPI)
- (GIMessageFilter *)_selectedFilter;
@end

NSString *GIFiltersPaneDelayedFiltersDidChange = @"GIFiltersPaneDelayedFiltersDidChange";

@implementation GIFiltersPane
/*" The controller for filter preferences. "*/

- (NSWindow *)window
{
    return [filtersTableView window];
}

- (GIMessageFilter *)_addFilterWithDictionary: (NSDictionary*) aDictionary
{
    // create empty filter and add filter to end of filters list
    GIMessageFilter *filter;
    int position;
    
    if (aDictionary) 
    {
        filter = [[GIMessageFilter alloc] initWithFilterDefinitionDictionary:aDictionary];
    } 
    else 
    {
        filter = [[GIMessageFilter alloc] init];
    }
    
    position = [[GIMessageFilter filters] count];
    [GIMessageFilter insertFilter:filter atPosition:position];
    
    // select new filter
    [filtersTableView selectRow:position byExtendingSelection: NO];
    
    return [filter autorelease];
}

- (IBAction)addFilter:(id)sender
    /*" Adds a new filter at the end of the list of filters. "*/
{
    [self _addFilterWithDictionary: nil];
}

- (IBAction)cloneFilter:(id)sender
{
    // copy dictionary of selected filter
    GIMessageFilter *filter;
    
    filter = [self _selectedFilter];
    
    if (filter) 
    {
        NSDictionary *filterDict;
        
        filterDict = [[filter filterDefinitionDictionary] copy];
        filter = [self _addFilterWithDictionary:filterDict];
        [filter setName:[NSLocalizedString(@"Copy of ", copy of filter name) stringByAppendingString: [filter name]]];
    } 
    else 
    {
        NSBeep();
    }
}

- (IBAction)removeFilter:(id)sender
    /*" Removes the selected filter. "*/
{
    int selectedRow;
    
    selectedRow = [filtersTableView selectedRow];
    
    if (selectedRow >= 0) 
    {
        [GIMessageFilter removeFilterAtPosition:selectedRow];
        [filtersTableView reloadData];
        if (selectedRow >= [[GIMessageFilter filters] count]) 
        {
            selectedRow -= 1;
        }
        
        if (selectedRow >= 0) 
        {
            [filtersTableView selectRow:selectedRow byExtendingSelection: NO];
        }
    }
}

- (IBAction)addExpression:(id)sender
{
    GIMessageFilter *filter;
    GIMessageFilterExpression *newExpression;
    NSMutableArray *expressions;
    
    filter = [self _selectedFilter];
    
    newExpression = [[GIMessageFilterExpression alloc] initWithExpressionDefinitionDictionary:[NSDictionary dictionary]];
    expressions = [[filter expressions] mutableCopy];
    
    [expressions addObject:newExpression];
    
    [filter setExpressions:expressions];
    
    [newExpression release];
    [expressions release];
    
    [matchingTableView reloadData];
}

- (IBAction)removeExpression:(id)sender
{
    NSMutableArray *expressions;
    GIMessageFilter *filter;
    int selectedRow;
    
    filter = [self _selectedFilter];
    selectedRow = [matchingTableView selectedRow];
    
    if ((selectedRow > 0) && (selectedRow < [[filter expressions] count])) 
    {
        expressions = [[filter expressions] mutableCopy];
        
        [expressions removeObjectAtIndex:selectedRow];
        
        [filter setExpressions:expressions];
        
        [expressions release];
        
        [matchingTableView reloadData];
    }
}

- (void) collectGroupPaths: (NSMutableArray*) paths andURIRepresenations:(NSMutableArray *)reps startingAtNode:(NSArray*) node prefix: (NSString*) prefix
{
    NSEnumerator *enumerator;
    id entry;
    
    enumerator = [node objectEnumerator];
    [enumerator nextObject]; // first position is node info
    
    while (entry = [enumerator nextObject])
    {
        if ([entry isKindOfClass:[NSMutableArray class]])
        {
            [self collectGroupPaths:paths andURIRepresenations:reps startingAtNode:entry prefix:[prefix stringByAppendingFormat: @"%@/", [[entry objectAtIndex:0] objectForKey:@"name"]]];
        } else {
            GIMessageGroup *group = [[OPPersistentObjectContext defaultContext] objectWithURLString: entry];
            [paths addObject:[prefix stringByAppendingString: [group valueForKey: @"name"]]];
            [reps addObject:entry];
        }
    }
}

- (void) updateDetailView
{
    GIMessageFilter *filter;
    int mode;
    NSEnumerator *enumerator;
    GIMessageFilterAction *action;
    
    [matchingTableView reloadData];
    
    filter = [self _selectedFilter];
    mode = [filter allExpressionsMustMatch] ? 1 : 0;
    
    // matching mode popup:
    [matchingModePopUp selectItemAtIndex:[matchingModePopUp indexOfItemWithTag:mode]];
    
    // setting up action definition
    
    // setting up popups
    
    // move parameter:
    NSMutableArray *groupPaths = [NSMutableArray array];
    NSMutableArray *reps = [NSMutableArray array];
    int i, count;
    
    [self collectGroupPaths:groupPaths andURIRepresenations:reps startingAtNode:[GIMessageGroup hierarchyRootNode] prefix: @""];
    
    count = [groupPaths count];

    [actionMoveParameter removeAllItems];

    for (i = 0; i < count; i++)
    {
        [actionMoveParameter addItemWithTitle:[groupPaths objectAtIndex:i]];
        [[actionMoveParameter lastItem] setRepresentedObject:[NSURL URLWithString:[reps objectAtIndex:i]]];
    }
    
    // switch checkboxes to default
    [actionMoveCheckbox setState:NSOffState];
    [actionPreventCheckbox setState:NSOffState];
    
     enumerator = [[filter actions] objectEnumerator];
     while (action = [enumerator nextObject])
     {
         switch ([action type]) 
         {
             case kGIMFActionTypePutInMessagebox:
             {
                 int index;
                 // checkbox
                 [actionMoveCheckbox setState:[action state]];
                 // parameter
                 index = [actionMoveParameter indexOfItemWithRepresentedObject:[NSURL URLWithString:[action parameter]]];
                 
                 if (index != -1) {
                     [actionMoveParameter selectItemAtIndex:index];
                 }
                 break;
             }
             case kGIMFActionTypePreventFurtherFiltering:
             {
                 [actionPreventCheckbox setState:[action state]];
                 break;
             }
                 // ## other types not yet implemented
             default:
                 break;
         }
     }
}

// notifications
- (void) filtersDidChange: (NSNotification*) aNotification
    /*" Triggers delayed notification. "*/
{
    NSNotification *notification;
    
    notification = [NSNotification notificationWithName:GIFiltersPaneDelayedFiltersDidChange object:self];
    [[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostWhenIdle coalesceMask:NSNotificationCoalescingOnName | NSNotificationCoalescingOnSender forModes: nil];
}

- (void) delayedFiltersDidChange: (NSNotification*) aNotification
    /*" Reloads table data. "*/
{
    [filtersTableView reloadData];
    [filtersTableView scrollRowToVisible:[filtersTableView selectedRow]];
    [self updateDetailView];
}

- (IBAction)modeChanged:(id)sender
{
    [[self _selectedFilter] setAllExpressionsMustMatch:[[matchingModePopUp selectedItem] tag] ? YES : NO];
}

- (IBAction)actionsChanged:(id)sender
{
    // actions
    NSMutableArray *actions;
    GIMessageFilterAction *action;
    NSDictionary *defDict;
    
    actions = [NSMutableArray array];
    
    defDict = [NSDictionary dictionary];
    
    // move action
    action = [[GIMessageFilterAction alloc] initWithActionDefinitionDictionary:defDict];
    [action setState:[actionMoveCheckbox state]];
    [action setParameter:[(NSURL *)[[actionMoveParameter selectedItem] representedObject] absoluteString]];
    [action setType:kGIMFActionTypePutInMessagebox];
    [actions addObject:action];
    [action release];
    
    // prevent further filtering action
    action = [[GIMessageFilterAction alloc] initWithActionDefinitionDictionary:defDict];
    [action setState:[actionPreventCheckbox state]];
    [action setType:kGIMFActionTypePreventFurtherFiltering];
    [actions addObject:action];
    [action release];

    [[self _selectedFilter] setActions:actions];
}

- (void) tableViewSelectionDidChange: (NSNotification*) aNotification
{
    if ([aNotification object] == filtersTableView)
    {
        [self updateDetailView];
    }
}

@end

@implementation GIFiltersPane (PrivateAPI)

- (GIMessageFilter *)_selectedFilter
{
    GIMessageFilter *result = nil;
    int selectedRow;
    
    selectedRow = [filtersTableView selectedRow];
    
    if (selectedRow >= 0)
    {
        result = [[GIMessageFilter filters] objectAtIndex:selectedRow];
    }
    return result;
}

@end

@implementation GIFiltersPane (OPPreferencePane)
/*" Overridden methods from #{OPPreferencePane} (see OPPreferences framework). "*/

- (void) awakeFromNib
{
    [[[matchingTableView tableColumnWithIdentifier: @"criteria"] dataCell] setFont:[NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSSmallControlSize]]];
    [[[matchingTableView tableColumnWithIdentifier: @"target"] dataCell] setFont:[NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSSmallControlSize]]];
}

- (NSString*) displayName
    /*" The name which is displayed in the preferences dialog. "*/
{
    return NSLocalizedString(@"Filters", Filter Preferences);
}

- (void) didSelect
/*" Invoked when the pref panel was selected. Initialization stuff. "*/
{
    // register for notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(filtersDidChange:) name: GIMessageFiltersDidChangeNotification object: nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(delayedFiltersDidChange:) name: GIFiltersPaneDelayedFiltersDidChange object:self];
    
    // Register to grok GIFILTERPREFTYPE drags
    [filtersTableView registerForDraggedTypes:[NSArray arrayWithObject:GIFILTERPREFTYPE]];
    [filtersTableView reloadData];
    [self updateDetailView];
}

- (void) willUnselect
/*" Invoked when the pref panel is about to be quit. "*/
{
    // unregister for notifications
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [headerFieldsForPopup release];
    headerFieldsForPopup = nil;
}

- (void) dealloc
/*" releases ivars. "*/
{    
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    [headerFieldsForPopup release];
    [super dealloc];
}

@end

@implementation GIFiltersPane (NSTableViewDataSource)
/*" Implementation of the methods for a NSTableView datasource. "*/

- (int)numberOfRowsInTableView: (NSTableView*) aTableView
{
    if (aTableView == filtersTableView)
    {
        return [[GIMessageFilter filters] count];
    } else {
        return [[[self _selectedFilter] expressions] count];
    }
}

- (id)tableView: (NSTableView*) aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
    if (aTableView == filtersTableView)
    {
        NSArray *filters = [GIMessageFilter filters];
        
        if (rowIndex >= [filters count]) 
        {
            return nil;
        }
        
        if ([[aTableColumn identifier] isEqualToString: @"enabled"]) 
        {
            return [NSNumber numberWithBool:[[filters objectAtIndex:rowIndex] isActive]];
        } 
        else 
        {
            return [[filters objectAtIndex:rowIndex] name];
        }
    }
    else // matching table view
    {
        GIMessageFilterExpression *expression;
        id result = nil;
        
        expression = [[[self _selectedFilter] expressions] objectAtIndex:rowIndex];
        
        if ([[aTableColumn identifier] isEqualToString: @"target"]) 
        {
            result = [expression subjectValue];
        } 
        else if ([[aTableColumn identifier] isEqualToString: @"argument"]) 
        {
            result = [expression argument];
        }
        
        return result ? result : @"";
    }
}

- (NSArray*) messageStatusPopUpTags
{
    static NSMutableArray *result = nil;
    
    if (! result) {
        result = [[NSMutableArray allocWithZone:[self zone]] init];
        
        [result addObject:[NSNumber numberWithInt:0]];
        [result addObject:[NSNumber numberWithInt:OPJunkMailStatus]];
        [result addObject:[NSNumber numberWithInt:OPSeenStatus]];
        [result addObject:[NSNumber numberWithInt:OPAnsweredStatus]];
    }
    
    return result;
}

- (NSArray*) messageStatusPopUpItems
{
    static NSMutableArray *result = nil;
    
    if (! result) {
        result = [[NSMutableArray allocWithZone:[self zone]] init];
        
        [result addObject:NSLocalizedString(@"None (no flag)", filter pref criteria name)];
        [result addObject:NSLocalizedString(@"Junk Mail", filter pref criteria name)];
        [result addObject:NSLocalizedString(@"Seen/Read", filter pref criteria name)];
        [result addObject:NSLocalizedString(@"Answered", filter pref criteria name)];
    }
    
    return result;
}

- (NSArray*) popUpButtonCellItemsForHeaderFields
{
    static NSMutableArray *result = nil;
    
    if (! result) {
        result = [[NSMutableArray allocWithZone:[self zone]] init];
        
        [result addObject:NSLocalizedString(@"contains", filter pref criteria name)];
        [result addObject:NSLocalizedString(@"does not contain", filter pref criteria name)];
        [result addObject:NSLocalizedString(@"starts with", filter pref criteria name)];
        [result addObject:NSLocalizedString(@"ends with", filter pref criteria name)];
        [result addObject:NSLocalizedString(@"equals", filter pref criteria name)];
    }
    
    return result;
}

- (NSArray*) popUpButtonCellTagsForHeaderFields
{
    static NSMutableArray *result = nil;
    
    if (! result) {
        result = [[NSMutableArray allocWithZone: [self zone]] init];
        
        [result addObject: [NSNumber numberWithInt: kGIMFCriteriaContains]];
        [result addObject: [NSNumber numberWithInt: kGIMFCriteriaDoesNotContain]];
        [result addObject: [NSNumber numberWithInt: kGIMFCriteriaStartsWith]];
        [result addObject: [NSNumber numberWithInt: kGIMFCriteriaEndsWith]];
        [result addObject: [NSNumber numberWithInt: kGIMFCriteriaEquals]];
    }
    
    return result;
}

- (NSArray*) popUpButtonCellItemsForFlags
{
    static NSMutableArray *result = nil;
    
    if (! result) {
        result = [[NSMutableArray allocWithZone: [self zone]] init];
        
        [result addObject: NSLocalizedString(@"has Flag", @"filter pref criteria name")];
        [result addObject: NSLocalizedString(@"does not have Flag", @"filter pref criteria name")];
        [result addObject: NSLocalizedString(@"has only Flag", @"filter pref criteria name")];
    }
    
    return result;
}

- (NSArray*) popUpButtonCellTagsForFlags
{
    static NSMutableArray *result = nil;
    
    if (! result) {
        result = [[NSMutableArray allocWithZone: [self zone]] init];
        
        [result addObject: [NSNumber numberWithInt: kGIMFCriteriaContains]];
        [result addObject: [NSNumber numberWithInt: kGIMFCriteriaDoesNotContain]];
        [result addObject: [NSNumber numberWithInt: kGIMFCriteriaEquals]];
    }
    
    return result;
}

- (void) tableView: (NSTableView*) aTableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)aTableColumn row:(int)row
{
    if ((aTableView == filtersTableView) && (row >= 0))
    {
        GIMessageFilter *filter = [[GIMessageFilter filters] objectAtIndex:row];
        
        if ( ([[aTableColumn identifier] isEqualToString: @"enabled"]) && (row >= 0) ) 
        {            
            [filter setIsActive: ! [filter isActive]]; // invert active state
        }
        else
        {
            [filter setName:object];
        }
    }
    else // matching table view
    {
        GIMessageFilterExpression *expression;
        
        expression = [[[self _selectedFilter] expressions] objectAtIndex:row];
        
        if ([[aTableColumn identifier] isEqual: @"target"])
        {
            if ([object isEqualToString:NSLocalizedString(@"<Message Status>", filter prefs sheet message status item)])
            {
                if ([expression subjectType] != kGIMFTypeFlag)
                {
                    [expression setSubjectType:kGIMFTypeFlag];
                    //                [self setLastArgumentValue:[expression argument]];
                    //                [expression setArgument:[self lastArgumentValue]];
                    [aTableView reloadData];
                }
            }
            else
            {
                if ([expression subjectType] != kGIMFTypeHeaderField)
                {
                    [expression setSubjectType:kGIMFTypeHeaderField];
                    //                [self setLastArgumentValue:[expression argument]];
                    //                [expression setArgument:[self lastArgumentValue]];
                    [aTableView reloadData];
                }
            }
            
            [expression setSubjectValue:object];
        }
        else if ([[aTableColumn identifier] isEqual: @"argument"])
        {
            switch ([expression subjectType])
            {
                case kGIMFTypeHeaderField:
                    [expression setArgument:object];
                    break;
                case kGIMFTypeFlag:
                {
                    NSArray *tags;
                    
                    tags = [self messageStatusPopUpTags];
                    [expression setFlagArgument:[[tags objectAtIndex:[object intValue]] intValue]];
                }
                    break;
                default:
                    break;
            }
        }
        else if ([[aTableColumn identifier] isEqual: @"criteria"])
        {
            NSArray *tags = nil;
            
            switch ([expression subjectType])
            {
                case kGIMFTypeHeaderField:
                    tags = [self popUpButtonCellTagsForHeaderFields];
                    break;
                case kGIMFTypeFlag:
                    tags = [self popUpButtonCellTagsForFlags];
                    break;
                default:
                    break;
            }
            
            [expression setCriteria:[[tags objectAtIndex:[object intValue]] intValue]];
        }
        else if ([[aTableColumn identifier] isEqual: @"remove"])
        {
            [self removeExpression:self];
        }
    }
}

- (void) tableView: (NSTableView*) aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
    if (aTableView == matchingTableView)
    {
        GIMessageFilterExpression *expression;
        
        expression = [[[self _selectedFilter] expressions] objectAtIndex:rowIndex];
        
        if ([[aTableColumn identifier] isEqual: @"target"]) 
        {
            [aCell setUsesDataSource: YES];
            [aCell setDataSource:self];
            [aCell setEditable: YES];
        }
        else if ([[aTableColumn identifier] isEqual: @"criteria"])
        {
            NSArray *items = nil;
            NSArray *tags = nil;
            int count, i;
            
            [aCell removeAllItems];
            
            switch ([expression subjectType])
            {
                case kGIMFTypeHeaderField:
                    items = [self popUpButtonCellItemsForHeaderFields];
                    tags = [self popUpButtonCellTagsForHeaderFields];
                    break;
                case kGIMFTypeFlag:
                    items = [self popUpButtonCellItemsForFlags];
                    tags = [self popUpButtonCellTagsForFlags];
                    break;
                default:
                    break;
            }
            
            count = [items count];
            for (i = 0; i < count; i++)
            {
                [aCell addItemWithTitle:[items objectAtIndex:i]];
                [[aCell lastItem] setTag:[[tags objectAtIndex:i] intValue]];
            }
            
            [aCell selectItemAtIndex:[aCell indexOfItemWithTag:[expression criteria]]];
        }
        else if ([[aTableColumn identifier] isEqual: @"argument"])
        {
            switch ([expression subjectType])
            {
                case kGIMFTypeHeaderField:
                    [aCell setFont:[NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSRegularControlSize]]];

                    break;
                case kGIMFTypeFlag:
                {
                    NSArray *items = nil;
                    NSArray *tags = nil;
                    int count, i;
                    
                    [aCell removeAllItems];
                    
                    items = [self messageStatusPopUpItems];
                    tags = [self messageStatusPopUpTags];
                    
                    count = [items count];
                    for (i = 0; i < count; i++)
                    {
                        [aCell addItemWithTitle:[items objectAtIndex:i]];
                        [[aCell lastItem] setTag:[[tags objectAtIndex:i] intValue]];
                    }
                    
                    [aCell selectItemAtIndex:[aCell indexOfItemWithTag:[expression flagArgument]]];
                }
                    break;
                default:
                    break;
            }
        }
    }
}

- (id)tableView: (NSTableView*) aTableView dataCellForTableColumn:(NSTableColumn *)aTableColumn row:(int)aRow
{
    static NSPopUpButtonCell *cell = nil;
    
    if ([self _selectedFilter])
    {
        GIMessageFilterExpression *expression;
        
        expression = [[[self _selectedFilter] expressions] objectAtIndex:aRow];
        
        if ([[aTableColumn identifier] isEqualToString: @"argument"])
        {
            if ([expression subjectType] == kGIMFTypeFlag)
            {
                if (! cell)
                {
                    cell = [[NSPopUpButtonCell alloc] initTextCell: @"" pullsDown: NO];
                    [cell setControlSize:NSRegularControlSize];
                    [cell setFont:[NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSSmallControlSize]]];
                    //[cell setControlSize:NSSmallControlSize];
                }
                
                return cell;
            }
        }
    }
    return nil;
}

@end

@implementation GIFiltersPane (DragNDrop)

- (BOOL)tableView: (NSTableView*) aTableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
    int index;
    NSArray *rows;
    GIMessageFilter *filter;
    
    rows = [[info draggingPasteboard] propertyListForType:GIFILTERPREFTYPE];
    
    NSAssert([rows count] == 1, @"More than one filter per drag is not supported");
    
    index = [[rows objectAtIndex:0] intValue];
    filter = [[GIMessageFilter filters] objectAtIndex:index];
    [GIMessageFilter moveFilter:filter toIndex:row];
    
    [filtersTableView selectRow:row byExtendingSelection: NO];
    
    return YES;
}

- (NSDragOperation)tableView: (NSTableView*) aTableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)operation
{
    [filtersTableView setDropRow:row dropOperation:NSTableViewDropAbove];
    return [info draggingSourceOperationMask];
}

- (BOOL)tableView: (NSTableView*) aTableView writeRows:(NSArray*) rows toPasteboard:(NSPasteboard *)pboard
{
    [pboard declareTypes:[NSArray arrayWithObject:GIFILTERPREFTYPE] owner:self];
    [pboard setPropertyList:rows forType:GIFILTERPREFTYPE];
    
    return YES;
}

@end


@interface GIFiltersPaneSheetController : NSObject
{    
    IBOutlet NSTextField *descriptionTextField;	/*" sheet description field "*/
    IBOutlet NSTableView *matchingTableView;	/*" the table view containing the matching criteria "*/
    IBOutlet NSPopUpButton *matchingModePopUp;	/*" sheet parameter matching mode "*/
    
    IBOutlet NSButton *actionMoveCheckbox;		/*" sheet checkbox move "*/
    IBOutlet NSPopUpButton *actionMoveParameter;	/*" sheet parameter move "*/
    IBOutlet NSButton *actionPreventCheckbox;		/*" sheet checkbox prevent further filtering "*/
    
    GIMessageFilter *filter;
    id _lastArgumentValue;
}

@end

@interface GIFiltersPaneSheetController (PrivateAPI)
@end

/* what's that? why here? 
@interface GIMessageboxHierarchyNode (GIFiltersPaneExtension)
- (void) appendNodeToArray: (NSMutableArray*) array;
@end

@implementation GIMessageboxHierarchyNode (GIFiltersPaneExtension)

- (void) appendNodeToArray: (NSMutableArray*)array
{
    NSEnumerator *enumerator;
    id entry;
    
    enumerator = [_entries objectEnumerator];
    while (entry = [enumerator nextObject]) {
        if ([entry isKindOfClass:[GIMessagebox class]]) {
            [array addObject:entry];
        } else {
            // descent
            [entry appendNodeToArray:array];
        }
    }
}

@end

*/

@implementation GIFiltersPaneSheetController

- (void) awakeFromNib
{
    static NSComboBoxCell *comboBoxCell = nil;
    static NSPopUpButtonCell *popUpButtonCell = nil;
    
    if (! comboBoxCell) {
        comboBoxCell = [[NSComboBoxCell alloc] init];
        [comboBoxCell setControlSize:NSSmallControlSize];
        
        popUpButtonCell = [[NSPopUpButtonCell alloc] initTextCell: @"" pullsDown: NO];
        [popUpButtonCell setControlSize:NSSmallControlSize];
    }
    
    [[matchingTableView tableColumnWithIdentifier: @"target"] setDataCell:comboBoxCell];
    [[matchingTableView tableColumnWithIdentifier: @"criteria"] setDataCell:popUpButtonCell];
}

- (void) dealloc
{
    [matchingTableView setDelegate: nil];
    [_lastArgumentValue release];
    _lastArgumentValue = nil;
    
    [super dealloc];
}

- (id)lastArgumentValue
{
    return _lastArgumentValue ? _lastArgumentValue : @"";
}

- (void) setLastArgumentValue:(id)value
{
    [value autorelease];
    _lastArgumentValue = [value retain];
}

- (IBAction) acceptSheet: (id) sender
{
    
    [filter setName:[descriptionTextField stringValue]];
        
    int mode = [[matchingModePopUp selectedItem] tag];
    
    [filter setAllExpressionsMustMatch:mode ? YES : NO];
    
    
    // actions
    NSMutableArray *actions;
    GIMessageFilterAction *action;
    NSDictionary *defDict;
    
    actions = [NSMutableArray array];
    [filter setActions:actions];
    
    defDict = [NSDictionary dictionary];
    
    // move action
    action = [[GIMessageFilterAction alloc] initWithActionDefinitionDictionary:defDict];
    [action setState:[actionMoveCheckbox state]];
    [action setParameter:[[actionMoveParameter selectedItem] representedObject]];
    [action setType:kGIMFActionTypePutInMessagebox];
    [actions addObject:action];
    [action release];
    
    // prevent further filtering action
    action = [[GIMessageFilterAction alloc] initWithActionDefinitionDictionary:defDict];
    [action setState:[actionPreventCheckbox state]];
    [action setType:kGIMFActionTypePreventFurtherFiltering];
    [actions addObject:action];
    [action release];
    
    // ## other actions missing
}

@end

@implementation GIFiltersPaneSheetController (PrivateAPI)

@end

@interface GIFiltersPaneSheetController (TableViewSupport)
- (id)lastArgumentValue;
- (void) setLastArgumentValue:(id)value;
@end

@implementation GIFiltersPaneSheetController (TableView)


@end

@implementation GIFiltersPane (ComboBox)

- (NSMutableArray *)headerFieldsForPopup
{
    if (! headerFieldsForPopup) 
    {
        headerFieldsForPopup = [[[NSUserDefaults standardUserDefaults] objectForKey: @"GIFiltersPaneHeaderFieldsForPopup"] mutableCopy];
        
        if (! headerFieldsForPopup) 
        {
            headerFieldsForPopup = [[NSMutableArray arrayWithObjects: @"From", @"To", @"Cc", @"To or Cc", @"Subject", @"Newsgroups", @"List-Id or To", @"Reply-To", nil] retain];
            [headerFieldsForPopup sortUsingSelector:@selector(caseInsensitiveCompare:)];
        }
    }
    
    return headerFieldsForPopup;
}

- (int)numberOfItemsInComboBoxCell: (NSComboBoxCell*) aComboBoxCell
{
    return [[self headerFieldsForPopup] count] + 1;
}

- (id)comboBoxCell: (NSComboBoxCell*) aComboBoxCell objectValueForItemAtIndex:(int)index
{
    if (index == [[self headerFieldsForPopup] count])
    {
        return NSLocalizedString(@"<Message Status>", filter prefs sheet message status item);
    } else {
        return [[self headerFieldsForPopup] objectAtIndex:index];
    }
}

@end
