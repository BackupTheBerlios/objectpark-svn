//
//  OPOutlineViewController.m
//  Gina
//
//  Created by Dirk Theisen on 21.11.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import "OPOutlineViewController.h"
#import <Foundation/NSDebug.h>
#import "OPPersistentObjectContext.h"

//@implementation OPPersistentObjectReference 
//
//- (id) initWithReferencedObjectOID: (OID) oid
//{
//	if (self = [super init]) {
//		referencedObjectOID = oid;
//	}
//	return self;
//}
//
//- (id <OPPersisting>) referencedObject
//{
//	id result = referencedObjectOID ? [[OPPersistentObjectContext defaultContext] objectForOID: referencedObjectOID] : nil;
//	return result;
//}
//
//- (OID) referencedObjectOID
//{
//	return referencedObjectOID;
//}
//
//@end

@implementation OPOutlineViewController

@synthesize suspendUpdatesUntilNextReloadData;
@synthesize refreshOutlineViewOnSetRootItem;

// -- binding stuff --

+ (void)initialize
{
    [self exposeBinding:@"rootItem"];	
}

- (Class)valueClassForBinding:(NSString *)binding
{
	return [NSObject class];	
}

- (id)observedObjectForRootItem { return observedObjectForRootItem; }

- (void)setObservedObjectForRootItem:(id)anObservedObjectForRootItem
{
    if (observedObjectForRootItem != anObservedObjectForRootItem) 
	{
        [observedObjectForRootItem release];
        observedObjectForRootItem = [anObservedObjectForRootItem retain];
    }
}

- (NSString *)observedKeyPathForRootItem 
{ 
	return observedKeyPathForRootItem; 
}

- (void)setObservedKeyPathForRootItem:(NSString *)anObservedKeyPathForRootItem
{
    if (observedKeyPathForRootItem != anObservedKeyPathForRootItem) {
        [observedKeyPathForRootItem release];
        observedKeyPathForRootItem = [anObservedKeyPathForRootItem copy];
    }
}

- (void)bind:(NSString *)bindingName
    toObject:(id)observableController
 withKeyPath:(NSString *)keyPath
     options:(NSDictionary *)options
{	
    if ([bindingName isEqualToString:@"rootItem"])
    {
		// observe the controller for changes
		[observableController addObserver:self
							   forKeyPath:keyPath 
								  options:0
								  context:nil];
		
		// register what controller and what keypath are 
		// associated with this binding
		[self setObservedObjectForRootItem:observableController];
		[self setObservedKeyPathForRootItem:keyPath];
		[self setRootItem: [observableController valueForKeyPath: keyPath]];
		
    } 
	
	[super bind:bindingName
	   toObject:observableController
	withKeyPath:keyPath
		options:options];
}

- (void)unbind:bindingName
{
    if ([bindingName isEqualToString:@"rootItem"])
    {
		[observedObjectForRootItem removeObserver:self
									   forKeyPath:observedKeyPathForRootItem];
		[self setObservedObjectForRootItem:nil];
		[self setObservedKeyPathForRootItem:nil];
//		[self reloadData];
    }	
		
	[super unbind:bindingName];
}

// -- regular stuff --

- (id)init
{
	if (self = [super init]) 
	{
		knownItems   = [[NSMutableSet alloc] init];		
		//expandedItems = [[NSMutableSet alloc] init];	
		doCalculateSelectedItemPaths = YES;
		refreshOutlineViewOnSetRootItem = YES;
	}
	return self;
}


//- (BOOL)outlineView:(NSOutlineView *)outlineView shouldExpandItem:(id)item
//{
//	[expandedItems addObject: item];
//	NSLog(@"Expanded item %@.\nNow %u expanded.", item, expandedItems.count);
//	return YES;
//}
//
//- (BOOL)outlineView:(NSOutlineView *)outlineView shouldCollapseItem:(id)item;
//{
//	[expandedItems removeObject: item];
//	NSLog(@"Collapsed item %@.\nNow %u expanded.", item, expandedItems.count);
//	return YES;
//}

- (NSSet*) knownItems
{
	return knownItems;
}

- (NSSet*) keyPathsAffectingDisplayOfItem: (id) item
{
// TODO: implement by returning a set of all table column identifiers.
	return nil;
}

- (void)suspendUpdates
{
	self.suspendUpdatesUntilNextReloadData = YES;
}

- (void)resumeUpdates
{
	[self reloadData];
	// Try to restore the selection:
	if (selectedItemsPaths.count) {
		[self setSelectedItemsPaths: selectedItemsPaths byExtendingSelection: NO];
	}
	
	[self willChangeValueForKey:@"selectedObjects"];
	[self didChangeValueForKey:@"selectedObjects"];
	[self willChangeValueForKey:@"selectedObject"];
	[self didChangeValueForKey:@"selectedObjects"];
}

- (void) reloadData
/*" Call this instead of calling reloadData on the outline. "*/
{
	self.suspendUpdatesUntilNextReloadData = NO;
	
	[self resetKnownItems];
	if (outlineView.dataSource) {
		[outlineView setDataSource:self];
		[outlineView reloadData];
	} else {
		[outlineView setDataSource:self];
		[outlineView reloadData];
	}
}

- (NSOutlineView*) outlineView
{
	return outlineView;
}

- (void) setOutlineView: (NSOutlineView*) newView
{
	if (newView != outlineView) {
		[self reloadData];
		[outlineView release];
		outlineView = [newView retain];
		outlineView.delegate = self;
	}
}

- (void)addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context
{
	[super addObserver: observer forKeyPath: keyPath options: options context: context];
	NSLog(@"%@ is now observing %@.%@", observer, self, keyPath);
}


- (id) rootItem
{
	return rootItem;
}

- (void)useClonedOutlineView
{
	NSOutlineView *oldOutlineView = outlineView;	
	NSView *nextKeyView = [oldOutlineView nextKeyView];
	NSView *previousKeyView = [oldOutlineView previousKeyView];
	
	oldOutlineView.dataSource = nil;
	oldOutlineView.delegate = nil;
	[oldOutlineView setNextKeyView:nil];
	
	NSOutlineView *newOutlineView = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:outlineView]];
	
	outlineView = newOutlineView;
		
	NSScrollView *scrollView = (id)[[oldOutlineView superview] superview];
	NSAssert([scrollView isKindOfClass:[NSScrollView class]], @"should be a scroll view");
	
	[scrollView setDocumentView:newOutlineView];
	
	newOutlineView.dataSource = self;
	newOutlineView.delegate = self;
	newOutlineView.nextKeyView = nextKeyView;
	[previousKeyView setNextKeyView:newOutlineView];
	
//	NSLog(@"old outline view = %@", oldOutlineView);
//	NSLog(@"new outline view = %@", newOutlineView);	
}

- (void) setRootItem: (id) newItem
{
	if (! [rootItem isEqual: newItem]) 
	{
		[outlineView setDataSource:nil];
		
		if (refreshOutlineViewOnSetRootItem)
		{
			[self useClonedOutlineView];
		}

		[rootItem removeObserver: self forKeyPath: [self childKey]];
		[self resetKnownItems];

		[rootItem release];
		rootItem = [newItem retain];
		[self reloadData];
		[rootItem addObserver:self forKeyPath: [self childKey] options: 
		 NSKeyValueObservingOptionOld context: NULL];
	}
}

- (void) addToKnownItems: (id) item
{
	if (item) {
		if (! [knownItems containsObject: item]) {
			[knownItems addObject: item];
			// Observe the child relation so we can react on that.
			if (NSDebugEnabled) NSLog(@"Controller observes %@.%@", item, [self childKey]);
			// Make KVO provide the old value. This way we can get rid of the keyPathsAffectingDisplayOfItem observation in case of a child deletion.
			[item addObserver: self forKeyPath: [self childKey] options: NSKeyValueObservingOptionOld context: NULL];
			// Also observe additional keyPaths that will affect display:
			for (NSString* keyPath in [self keyPathsAffectingDisplayOfItem: item]) {
				[item addObserver: self forKeyPath: keyPath options: 0 context: outlineView];
			}
		}
	} else {
		NSLog(@"Warning: nil item in outline data detected.");
	}
}

- (void) removeFromKnownItems: (id) item
{
	if ([knownItems containsObject: item]) {
		for (NSString* keyPath in [self keyPathsAffectingDisplayOfItem: item]) {
			[item removeObserver: self forKeyPath: keyPath];
		}
		[knownItems removeObject: item];
	}
}

- (void) resetKnownItems
{
	id item;
	while (item = [knownItems anyObject]) {
		[self removeFromKnownItems: item]; // also removes item from knownItems
	}
}

- (void) observeValueForKeyPath: (NSString*) keyPath 
					   ofObject: (id) object 
						 change: (NSDictionary*) change 
						context: (void*) context
{
	if (context == outlineView) {
		// just redisplay the affected item:
		// if (NSDebugEnabled) NSLog(@"Redisplaying %@ due to change of %@ (%@)", object, keyPath, change);
		if (!self.suspendUpdatesUntilNextReloadData)
		{
			[outlineView reloadItem:object reloadChildren:YES]; 
		}
		// - (void)_setNeedsDisplayInRow:(int)fp8;

	}
	
	if ([keyPath isEqualToString: [self childKey]]) {
		//NSLog(@"outlineview %@ change: %@", self, change);
		
		int changeKind = [[change objectForKey: NSKeyValueChangeKindKey] unsignedIntValue];
		// Get rid of knownItems in the old relation state:
		if (changeKind == NSKeyValueChangeRemoval || changeKind == NSKeyValueChangeReplacement) {
			for (id item in [change objectForKey: NSKeyValueChangeOldKey]) {
				[self removeFromKnownItems: item];
			}
		}		
		// try to keep the selection:
		
		if (object == rootItem) object = nil;
		if (! self.suspendUpdatesUntilNextReloadData) {
			[outlineView reloadItem: object reloadChildren: YES]; 
			if (selectedItemsPaths.count && (object == nil || [outlineView isItemExpanded: object])) {
				NSLog(@"Selecting %u items paths", selectedItemsPaths.count);
				[self setSelectedItemsPaths: selectedItemsPaths byExtendingSelection: NO];
			}
		}
		
		// TODO: if we got a qualified notification, could we be more efficient?
	}
	else if ([keyPath isEqualToString: [self observedKeyPathForRootItem]])
	{ 
		// rootItem changed
		id newRootItem = [observedObjectForRootItem valueForKeyPath: observedKeyPathForRootItem];
		[self setRootItem: newRootItem];
	}
	else 
	{
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}	
}

- (NSString *)childKey
{
	return childKey;
}

- (void) setChildKey: (NSString*) aChildKey
/*" This can never change once it has been set to an non-nil value. Raises otherwise. "*/
{
	NSParameterAssert(childKey == nil || [childKey isEqualToString:aChildKey]);
	childKey = [aChildKey copy];
}

- (NSString*) childCountKey
/*" An items KVC-Key pointing to the child count. Optimization, optional. "*/
{
	return childCountKey;
}

- (void) setChildCountKey: (NSString*) aChildCountKey
/*" This can never change once it has been set to an non-nil value. Raises otherwise. "*/
{
	NSParameterAssert(childCountKey == nil || [childCountKey isEqualToString:aChildCountKey]);
	childCountKey = [aChildCountKey copy];
}

- (id) outlineView: (NSOutlineView*) outlineView child: (NSInteger) index ofItem: (id) item
{
	if (! item) item = [self rootItem];
	id result = [[item valueForKeyPath: [self childKey]] objectAtIndex: index];
	
	[self addToKnownItems: result]; // does nothing, if already contained
	return result;
}

- (BOOL) outlineView: (NSOutlineView*) anOutlineView isItemExpandable: (id) item
{
	NSParameterAssert(anOutlineView == outlineView);
	return [self outlineView: anOutlineView numberOfChildrenOfItem: item] > 1;
}

- (NSInteger)outlineView:(NSOutlineView *)anOutlineView numberOfChildrenOfItem:(id)item
{
	NSParameterAssert(anOutlineView == outlineView);
	if (! item) item = [self rootItem];
	unsigned count = 0;
	
	if (childCountKey)
	{
		id childCountObject = [item valueForKey:childCountKey];
		if ([childCountObject respondsToSelector:@selector(unsignedIntValue)])
		{
			count = [childCountObject unsignedIntValue];
		}
	}
	else
	{
		count = [[item valueForKeyPath:[self childKey]] count];
	}
	
	return count;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	if (! item) 
	{
		item = [self rootItem];
	} 
	else 
	{
		if (NSDebugEnabled) NSAssert([knownItems containsObject:item], @"item not known!?");
	}
		
	NSString *columnKey = [tableColumn identifier];
	if ([columnKey hasPrefix:@"empty"]) return @"";
	id result = columnKey ? [item valueForKey:columnKey] : nil;
	return result;
}

- (void)scrollSelectionToVisible
{
	[outlineView scrollRowToVisible:[[outlineView selectedRowIndexes] lastIndex]];
}

- (void) outlineViewSelectionDidChange: (NSNotification*) notification
{
	if (outlineView && doCalculateSelectedItemPaths) {
		NSIndexSet* selectedRowIndexes = [outlineView selectedRowIndexes];

		[selectedItemsPaths release];
		selectedItemsPaths = [[NSMutableArray alloc] initWithCapacity: selectedRowIndexes.count];
		
		NSUInteger index = 0;
		while ((index = [selectedRowIndexes indexGreaterThanOrEqualToIndex:index]) != NSNotFound) {
			
			id item = [outlineView itemAtRow: index];
			[selectedItemsPaths addObject: [self itemPathForItem: item]];
			index += 1;
		}
		NSLog(@"Selected %u items paths.", selectedItemsPaths.count);
	}
	
	[self willChangeValueForKey:@"selectedObject"];
	[self didChangeValueForKey:@"selectedObject"];
	[self willChangeValueForKey:@"selectedObjects"];
	[self didChangeValueForKey:@"selectedObjects"];
}

- (NSArray *)selectedObjects
{
	NSMutableArray *result = [NSMutableArray array];
	
	if (outlineView) {
		NSIndexSet* selectedRowIndexes = [outlineView selectedRowIndexes];
		NSUInteger index = 0;
		
		while ((index = [selectedRowIndexes indexGreaterThanOrEqualToIndex:index]) != NSNotFound) {
			[result addObject:[outlineView itemAtRow:index]];
			index += 1;
		}
	}
	return result;
}

- (NSArray*) selectedItemsPaths
{
	return [[selectedItemsPaths retain] autorelease];
}

- (void) setSelectedObjects: (NSArray*) anArray
{	
	NSBeep();
	
//	if (anArray.count) {
//		NSUInteger row;
//		NSMutableIndexSet *indexesToSelect = [NSMutableIndexSet indexSet];
//		
//		for (id itemToSelect in anArray) {
//			row = [outlineView rowForItem:itemToSelect];
//			[indexesToSelect addIndex: row];
//		}
//		
//		[outlineView selectRowIndexes:indexesToSelect byExtendingSelection:NO];
//		
//		//[outlineView scrollRowToVisible: row];
//	}
}

- (NSUInteger) rowForItemPath: (NSArray*) path
/*" Also expands the items in the given path as necessary. "*/
{
	NSInteger row = NSNotFound;
	id lastItem = nil;
	if (path.count) {
		row = -1;
		// root index is the minimum index the first item on the path can be on.
		NSArray* container = [self.rootItem valueForKey: childKey];
		for (id item in path) {
			
			if (lastItem) {
				if ([self outlineView: outlineView isItemExpandable: lastItem]) {
					[outlineView expandItemAtRow: row expandChildren: NO];
					container = [lastItem valueForKey: childKey];
					NSRect redisplayRect = NSUnionRect([outlineView rectOfRow: row], [outlineView rectOfRow: row + container.count]);
					[outlineView setNeedsDisplayInRect: redisplayRect];
				} else {
					break;
				}	
			}
			
			NSUInteger containerOffset = [container indexOfObjectIdenticalTo: item];
			
			// Now do a linear search for item. This only happens if items are expanded on the way:
			if (containerOffset == NSNotFound) 
				return NSNotFound;
			
			row += containerOffset;
			
			//row+=1; // adds one in order to skip the container item
			while (row < [outlineView numberOfRows] && [outlineView itemAtRow: row] != item) {
				row += 1;
			}
			if (row >= [outlineView numberOfRows]) {
				NSLog(@"Unable to find item %@ in outline view.", item);
				break;
			}
			lastItem = item;
		}
	}
	return row;
}

- (void) setSelectedItemsPaths: (NSArray*) itemPaths byExtendingSelection: (BOOL) extend
/*" Tries to set the selection to the item paths given as an array of arrays. "*/
{
	[selectedItemsPaths autorelease]; selectedItemsPaths = nil; //[[NSMutableArray alloc] initWithCapacity: itemPaths.count];
	if (itemPaths.count) {
		BOOL allPathsSelected = YES;
		doCalculateSelectedItemPaths = NO;
		NSInteger row = NSNotFound;
		//NSLog(@"%@ selecting items at paths: %@", self, itemPaths);
		//[self willChangeValueForKey: @"selectedItems"];
		for (NSArray* path in itemPaths) {
			row = [self rowForItemPath: path];
			if (row != NSNotFound) {
				//[outlineView selectRow: row byExtendingSelection: extend]; // deprecated
				[outlineView selectRowIndexes: [NSIndexSet indexSetWithIndex: row] byExtendingSelection: extend];
				NSIndexSet*	selectionIndexes = [outlineView selectedRowIndexes];
				if (! [selectionIndexes containsIndex: row]) {
					NSLog(@"row not selected");
					allPathsSelected = NO;
				} else {
					// row was successfully selected.
					[selectedItemsPaths addObject: path];
				}
				extend = YES;
			}
		}
		
		doCalculateSelectedItemPaths = YES;
		if (allPathsSelected) {
			selectedItemsPaths = [itemPaths retain];
		} else {
			[self outlineViewSelectionDidChange: nil]; // rebuild selectedItemsPaths
		}
		
		//[self didChangeValueForKey: @"selectedItems"];
	} else {
		if (! extend) [outlineView deselectAll: self];
	}	
}

//- (void) setSelectedObject: (id) object
//{
//	self.selectedObjects = [NSArray arrayWithObject: object];
//}

- (id) selectedObject
{
	NSAssert([outlineView allowsMultipleSelection] == NO, @"selectedObject only available for single selection outline views.");
	return self.selectedObjects.lastObject;
}

- (void) dealloc 
{
	[self resetKnownItems];
	[knownItems release];
	//[expandedItems release];
	[selectedItemsPaths release];
	[childKey release];
	[rootItem release];
	[super dealloc];
}

@end

@implementation OPOutlineViewController (ConvenientSlowHelpers)

//- (BOOL)item:(id)pathCandidate isOnPathToItem:(id)item itemPath:(NSMutableArray *)itemPath
//{
//	if (pathCandidate == item)
//	{
//		[itemPath addObject:pathCandidate];
//		return YES;
//	}
//	
//	NSArray *children = [pathCandidate valueForKeyPath:[self childKey]];
//	if (children.count)
//	{
//		for (id child in children)
//		{
//			if ([self item:child isOnPathToItem:item itemPath:itemPath])
//			{
//				[itemPath insertObject:pathCandidate atIndex:0];
//				return YES;
//			}
//		}
//	}
//	
//	return NO;
//}

- (NSArray *)itemPathForItem:(id)item
/*" Returns the path to the item given, excluding the root item. "*/
{
	if (!item) return nil;
	
	NSMutableArray *result = [NSMutableArray array];
	
	while (item)
	{
		[result insertObject:item atIndex:0];
		item = [outlineView parentForItem:item];
	}
	
	return result;
}

@end

@implementation NSOutlineView (OPPrivate)

struct __REFlags {
    unsigned int expandable:1;
    unsigned int expanded:1;
    unsigned int inited:1;
    unsigned int initedItemData:1;
    unsigned int initedIsExpandableData:1;
    unsigned int reserved:27;
};

struct __NSOVRowEntry {
    struct __NSOVRowEntry *_field1;
    int _field2;
    id item;
    short _field4;
    int _field5;
    struct __NSOVRowEntry **_field6;
    int *_field7;
    struct __REFlags flags;
};


- (void) expandItemAtRow: (int) row expandChildren: (BOOL) expand
{
//	BOOL isExpanded = [self isItemExpandedAtRow: row];
//	if (isExpanded && !expand) return; // Nothing to do, if the item is already expended
	
	if (row < [self numberOfRows]) {
		
//		struct __REFlags flags;
//		flags.expanded = YES;
		
		struct __NSOVRowEntry* rowEntry = [self _rowEntryForRow: row requiredRowEntryLoadMask: -1];
		@try {
			if (rowEntry && ![self isItemExpanded: rowEntry->item]) {
				if (rowEntry && !(rowEntry->flags.expanded)) { 
					[self _expandItemEntry: rowEntry expandChildren: expand];
					[self noteNumberOfRowsChanged];
				}
			}
		} @catch (NSException* e) {
			// ignore :-(
		}
	}
}

/*" Does not seem to work at all as sometimes struct members are non initialized "*/
- (BOOL) isItemExpandedAtRow: (int) row
{
	if (row < [self numberOfRows]) {
		struct __NSOVRowEntry* rowEntry = [self _rowEntryForRow: row requiredRowEntryLoadMask: 0];
		return rowEntry ? rowEntry->flags.expanded : NO;
	}
	return NO;
}

@end
