//
//  OPOutlineViewController.m
//  Gina
//
//  Created by Dirk Theisen on 21.11.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import "OPOutlineViewController.h"


@implementation OPOutlineViewController

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

- (NSString *)observedKeyPathForRootItem { return observedKeyPathForRootItem; }
- (void)setObservedKeyPathForRootItem:(NSString *)anObservedKeyPathForRootItem
{
    if (observedKeyPathForRootItem != anObservedKeyPathForRootItem) 
	{
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
    }
	
	[super bind:bindingName
	   toObject:observableController
	withKeyPath:keyPath
		options:options];
	
	[self reloadData];
}

- (void)unbind:bindingName
{
    if ([bindingName isEqualToString:@"rootItem"])
    {
		[observedObjectForRootItem removeObserver:self
											  forKeyPath:observedKeyPathForRootItem];
		[self setObservedObjectForRootItem:nil];
		[self setObservedKeyPathForRootItem:nil];
    }	
	
	[super unbind:bindingName];
	[self reloadData];
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

- (void) resetKnownItems
{
	for (id item in knownItems) {
		[item removeObserver: self forKeyPath: [self childKey]];
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
		[rootItem addObserver: self forKeyPath: [self childKey] options: 0 context: NULL];
		[self reloadData];
	}
}

- (void) observeValueForKeyPath: (NSString*) keyPath 
					   ofObject: (id) object 
						 change: (NSDictionary*) change 
						context: (void*) context
{
	if ([keyPath isEqualToString:[self childKey]])
	{
		// if the cildKey relation changes, reload that item:
		if (object==rootItem) object = nil;
		[outlineView reloadItem: object reloadChildren: YES]; 
		// todo: if we got a qualified notification, could we be more efficient?
	}
	else
	{
		// rootItem changed
		id newRootItem = [observedObjectForRootItem valueForKeyPath:observedKeyPathForRootItem];
		[self setRootItem:newRootItem];
	}
}

- (NSString*) childKey
{
	return childKey ? childKey : @"children";
}

- (void) setChildKey: (NSString*) aChildKey
/*" This can never change once it has been set to an non-nil value. Raises otherwise. "*/
{
	NSParameterAssert(childKey == nil || [childKey isEqualToString: aChildKey]);
	childKey = [aChildKey copy];
}

- (id) outlineView: (NSOutlineView*) outlineView child: (NSInteger) index ofItem: (id) item
{
	if (! item) item = [self rootItem];
	id result = [[item valueForKeyPath: [self childKey]] objectAtIndex: index];
	if (! [knownItems containsObject: result]) {
		[knownItems addObject: result];
		// Observe the child relation so we can react on that.
		NSLog(@"Controller observes %@.%@", result, [self childKey]);
		[result addObserver: self forKeyPath: [self childKey] options: 0 context: NULL];
	}
	return result;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	if (! item) item = [self rootItem];
	return [[item valueForKeyPath: [self childKey]] count] > 1;
}

- (NSInteger) outlineView: (NSOutlineView*) outlineView numberOfChildrenOfItem: (id) item
{
	if (! item) item = [self rootItem];
	return [[item valueForKeyPath: [self childKey]] count];
}

- (id) outlineView: (NSOutlineView*) outlineView objectValueForTableColumn: (NSTableColumn*) tableColumn byItem: (id) item
{
	if (! item) {
		item = [self rootItem];
	} else {
		NSAssert([knownItems containsObject: item], @"item not known!?");
	}
	NSString* columnKey = [tableColumn identifier];
	if ([columnKey hasPrefix:@"empty"]) return @"";
	return [item valueForKey: columnKey];
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

- (void) dealloc 
{
	[knownItems release];
	[childKey release];
	[rootItem release];
	[super dealloc];
}

@end
