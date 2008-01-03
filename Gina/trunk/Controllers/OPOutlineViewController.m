//
//  OPOutlineViewController.m
//  PersistenceKit-Test
//
//  Created by Dirk Theisen on 21.11.07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "OPOutlineViewController.h"


@implementation OPOutlineViewController

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
		[item removeObserver: self forKeyPath: childKey];
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
		[rootItem removeObserver: self forKeyPath: childKey];
		[rootItem release];
		rootItem = [newItem retain];
		[rootItem addObserver: self forKeyPath: childKey options: 0 context: NULL];
		[self reloadData];
	}
}

- (void) observeValueForKeyPath: (NSString*) keyPath 
					   ofObject: (id) object 
						 change: (NSDictionary*) change 
						context: (void*) context
{
	// if the cildKey relation changes, reload that item:
	if (object==rootItem) object = nil;
	[outlineView reloadItem: object reloadChildren: YES]; 
	// todo: if we got a qualified notification, could we be more efficient?
}

- (NSString*) childKey
{
	return childKey;
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
	id result = [[item valueForKeyPath: childKey] objectAtIndex: index];
	if (! [knownItems containsObject: result]) {
		[knownItems addObject: result];
		// Observe the child relation so we can react on that.
		NSLog(@"Controller observes %@.%@", result, childKey);
		[result addObserver: self forKeyPath: childKey options: 0 context: NULL];
	}
	return result;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	if (! item) item = [self rootItem];
	return [[item valueForKeyPath: childKey] count] > 1;
}

- (NSInteger) outlineView: (NSOutlineView*) outlineView numberOfChildrenOfItem: (id) item
{
	if (! item) item = [self rootItem];
	return [[item valueForKeyPath: childKey] count];
}

- (id) outlineView: (NSOutlineView*) outlineView objectValueForTableColumn: (NSTableColumn*) tableColumn byItem: (id) item
{
	if (! item) {
		item = [self rootItem];
	} else {
		NSAssert([knownItems containsObject: item], @"item not known!?");
	}
	NSString* columnKey = [tableColumn identifier];
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
