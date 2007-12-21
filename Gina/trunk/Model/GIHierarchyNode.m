//
//  GIHierarchyNode.m
//  BTreeLite
//
//  Created by Dirk Theisen on 07.11.07.
//  Copyright 2007 Dirk Theisen. All rights reserved.
//

#import "GIHierarchyNode.h"
#import "OPFaultingArray.h"


@implementation GIHierarchyNode

@synthesize name, children;

+ (BOOL) cachesAllObjects
{
	return YES;
}


- (void) dealloc
{
	[name release];
	[children release];
    [super dealloc];
}

- (void) willDelete
{
	// delete dependent objects
	[children makeObjectsPerformSelector: @selector(willDelete)]; // ask user first!
	[super willDelete];
}

- (BOOL) canHaveChildren
{
	return YES;
}

- (id) init 
{
	if (self = [super init]) {
		if ([self canHaveChildren]) {
			children = [[OPFaultingArray alloc] init];
		}
	}
	return self;
}



- (id) initWithCoder: (NSCoder*) coder
{
	name = [coder decodeObjectForKey: @"name"];
	children = [coder decodeObjectForKey: @"children"];
	
	return self;
}

- (void) encodeWithCoder: (NSCoder*) coder
{
	
	[coder encodeObject: name forKey: @"name"];
	[coder encodeObject: children forKey: @"children"];
}

- (NSString*) description
{
	return [NSString stringWithFormat: children ? @"%@ '%@' with %u children" : @"%@ '%@'", [super description], [self valueForKey: @"name"], [children count]];
}



@end
