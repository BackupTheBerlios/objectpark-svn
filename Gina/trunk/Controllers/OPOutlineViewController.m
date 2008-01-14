//
//  OPOutlineViewController.m
//  Gina
//
//  Created by Dirk Theisen on 21.11.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import "OPOutlineViewController.h"
#import <Foundation/NSDebug.h>

@implementation OPOutlineViewController

// -- binding stuff --

+ (void)initialize
{
    [self exposeBinding: @"rootItem"];	
    [self exposeBinding: @"selectedObjects"];	
}

- (Class) valueClassForBinding: (NSString*) binding
{
	if ([binding isEqualToString:@"selectedObjects"]) {
		return [NSArray class];
	} else {
		return [NSObject class];	
	}
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

- (NSString *)observedKeyPathForRootItem { return observedKeyPathForRootItem; }

- (void)setObservedKeyPathForRootItem:(NSString *)anObservedKeyPathForRootItem
{
    if (observedKeyPathForRootItem != anObservedKeyPathForRootItem) 
	{
        [observedKeyPathForRootItem release];
        observedKeyPathForRootItem = [anObservedKeyPathForRootItem copy];
    }
}

- (id)observedObjectForSelectedObjects { return observedObjectForSelectedObjects; }

- (void)setObservedObjectForSelectedObjects:(id)anObservedObjectForSelectedObjects
{
    if (observedObjectForSelectedObjects != anObservedObjectForSelectedObjects) 
	{
        [observedObjectForSelectedObjects release];
        observedObjectForSelectedObjects = [anObservedObjectForSelectedObjects retain];
    }
}

- (NSString *)observedKeyPathForSelectedObjects { return observedKeyPathForSelectedObjects; }

- (void)setObservedKeyPathForSelectedObjects:(NSString *)anObservedKeyPathForSelectedObjects
{
    if (observedKeyPathForSelectedObjects != anObservedKeyPathForSelectedObjects) 
	{
        [observedKeyPathForSelectedObjects release];
        observedKeyPathForSelectedObjects = [anObservedKeyPathForSelectedObjects copy];
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
		
		[self reloadData];
    }
	else if ([bindingName isEqualToString:@"selectedObjects"])
    {
		// observe the controller for changes
		[observableController addObserver:self
							   forKeyPath:keyPath 
								  options:0
								  context:nil];
		
		// register what controller and what keypath are 
		// associated with this binding
		[self setObservedObjectForSelectedObjects:observableController];
		[self setObservedKeyPathForSelectedObjects:keyPath];	
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
		[self reloadData];
    }	
	else if ([bindingName isEqualToString:@"selectedObjects"])
    {
		[observedObjectForSelectedObjects removeObserver:self
											  forKeyPath:observedKeyPathForSelectedObjects];
		[self setObservedObjectForSelectedObjects:nil];
		[self setObservedKeyPathForSelectedObjects:nil];
    }
	
	[super unbind:bindingName];
}

// -- regular stuff --

- (id) init
{
	if (self = [super init]) {
		knownItems = [[NSMutableSet alloc] init];
	}
	return self;
}

- (NSSet*) knownItems
{
	return knownItems;
}

- (NSSet*) keyPathsAffectingDisplayOfItem: (id) item
{
	return nil;
}

- (void) resetKnownItems
{
	for (id item in knownItems) {
		[item removeObserver: self forKeyPath: [self childKey]];
		for (id keyPath in [self keyPathsAffectingDisplayOfItem: item]) {
			[item removeObserver: self forKeyPath: keyPath];
		}
	}
	[knownItems removeAllObjects];
}

- (void) reloadData
/*" Call this instead of calling reloadData on the outline. "*/
{
	[self resetKnownItems];
	[outlineView reloadData];
}

- (id) rootItem
{
	return rootItem;
}

- (void) setRootItem: (id) newItem
{
	if (! [rootItem isEqual: newItem]) {
		[rootItem removeObserver: self forKeyPath: [self childKey]];
		[rootItem release];
		rootItem = [newItem retain];
		[rootItem addObserver:self forKeyPath: [self childKey] options: 0 context: NULL];
		[self reloadData];
	}
}

- (void) observeValueForKeyPath: (NSString*) keyPath 
					   ofObject: (id) object 
						 change: (NSDictionary*) change 
						context: (void*) context
{
	if (context == outlineView) {
		// just redisplay the affected item:
		[outlineView reloadItem: object reloadChildren: NO]; 
	}
	
	if ([keyPath isEqualToString:[self childKey]])
	{
		// if the childKey relation changes, reload that item:
		if (object == rootItem) object = nil;
		[outlineView reloadItem: object reloadChildren: YES]; 
		// todo: if we got a qualified notification, could we be more efficient?
	}
	else if ([keyPath isEqualToString: [self observedKeyPathForRootItem]])
	{ 
		// rootItem changed
		id newRootItem = [observedObjectForRootItem valueForKeyPath: observedKeyPathForRootItem];
		[self setRootItem: newRootItem];
	}
	else if ([keyPath isEqualToString:[self observedKeyPathForSelectedObjects]])
	{ 
		// selectedObjects changed
		id newSelectedObjects = [observedObjectForSelectedObjects valueForKeyPath: [self observedKeyPathForSelectedObjects]];
		[self setSelectedObjects:newSelectedObjects];
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



- (void) addToKnownItems: (id) item
{
	if (item) {
		[knownItems addObject: item];
		// Observe the child relation so we can react on that.
		if (NSDebugEnabled) NSLog(@"Controller observes %@.%@", item, [self childKey]);
		[item addObserver:self forKeyPath:[self childKey] options:0 context:NULL];
		// Also observe additional keyPaths that will affect display:
		for (NSString* keyPath in [self keyPathsAffectingDisplayOfItem: item]) {
			[item addObserver: self forKeyPath: keyPath options: 0 context: outlineView];
		}
	} else {
		NSLog(@"Warning: nil item in outline data detected.");
	}
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
	if (! item) item = [self rootItem];
	id result = [[item valueForKeyPath:[self childKey]] objectAtIndex:index];
	
#warning hack to circumvent bug. Remove later:
	static NSDictionary* hackDict = nil; 
	
	if (!result) {
		if (! hackDict) hackDict = [[NSDictionary alloc] init];
		result = hackDict;
	}
	
	if (! [knownItems containsObject:result]) {
		[self addToKnownItems: result];
	}
	return result;
}

- (BOOL) outlineView: (NSOutlineView*) anOutlineView isItemExpandable: (id) item
{
	NSParameterAssert(anOutlineView == outlineView);
	return [self outlineView: anOutlineView numberOfChildrenOfItem: item] > 1;
}

- (NSInteger)outlineView:(NSOutlineView *)anOutlineView numberOfChildrenOfItem: (id) item
{
	NSParameterAssert(anOutlineView == outlineView);
	if (! item) item = [self rootItem];
	unsigned count = childCountKey 
	? [[item valueForKey: childCountKey] unsignedIntValue] 
	: [[item valueForKeyPath:[self childKey]] count];
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
	return [item valueForKey:columnKey];
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
	[self willChangeValueForKey:@"selectedObjects"];
	[self didChangeValueForKey:@"selectedObjects"];
}

- (NSArray *)selectedObjects
{
	NSMutableArray *result = [NSMutableArray array];
	NSIndexSet *selectedRowIndexes = [outlineView selectedRowIndexes];
	NSUInteger index = 0;
	
	while ((index = [selectedRowIndexes indexGreaterThanOrEqualToIndex:index]) != NSNotFound)
	{
		[result addObject:[outlineView itemAtRow:index]];
		index += 1;
	}
	
	return result;
}

- (void)setSelectedObjects:(NSArray *)anArray
{	
	[outlineView deselectAll:self];
	
	for (id itemToSelect in anArray)
	{
		[outlineView selectRow:[outlineView rowForItem:itemToSelect] byExtendingSelection:YES];
	}
	
	if ([anArray count])
	{
		[outlineView scrollRowToVisible:[outlineView rowForItem:[anArray lastObject]]];
	}
}

- (void) dealloc 
{
	[self resetKnownItems];
	[knownItems release];
	[childKey release];
	[rootItem release];
	[super dealloc];
}

@end
