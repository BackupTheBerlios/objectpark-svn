//
//  OPDerivedValue.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 20.07.07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "OPDerivedValue.h"


@implementation OPDerivedValue


+ (NSIndexSet*) allIndexes
{
	static NSIndexSet* _allIndexes = nil;
	if (! _allIndexes) {
		_allIndexes = [[NSIndexSet indexSetWithIndexesInRange: NSMakeRange(0, 20000000)] retain];
	}

	return _allIndexes;
}
 
- (long long) initialValue
{
	return 0;
}

- (void) elementValueDidAdd: (id) elementValue
{
	value += [elementValue longLongValue];
}

- (void) elementValueDidRemove: (id) elementValue
{
	value -= [elementValue longLongValue];
}

- (long long) value;
{
	if (value == NSNotFound) {
		// Calculate value over all elements:
		value = [self initialValue];
		int i;
		int imax = [array count];
		for (i=0; i< imax; i++) {
			id element = [array objectAtIndex: i];
			id elementValue = [element valueForKeyPath: keyPath];
			[self elementValueDidAdd: elementValue];
		}
		[array addObserver: self 
		toObjectsAtIndexes: [[self class] allIndexes] 
				forKeyPath: keyPath 
				   options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld 
				   context: NULL];	
	}
	return value;
}

- (void) observeValueForKeyPath: (NSString*) keyPath ofObject: (id) object change: (NSDictionary*) change context: (void*) context
{
	NSLog(@"%@ did observe %@", self, change);
}


- (void) setValue: (long long) newValue 
{
	[self willChangeValueForKey: @"value"];
	value = newValue;
	[self didChangeValueForKey: @"value"];
}

- (id) initWithArray: (NSArray*) array elementKeyPath: (NSString*) aKeyPath
{
	if (self = [super init]) {
		keyPath = [aKeyPath retain];	
		value = NSNotFound;
	} 
	return self;
}

- (void) dealloc
{
	[array removeObserver: self fromObjectsAtIndexes: [[self class] allIndexes] forKeyPath: keyPath];
	[array release];
	[keyPath release];
	[super dealloc];
}


@end
