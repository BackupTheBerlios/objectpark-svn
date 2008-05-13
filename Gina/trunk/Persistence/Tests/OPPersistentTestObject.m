//
//  OPPersistentTestObject.m
//  Gina
//
//  Created by Dirk Theisen on 23.12.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import "OPPersistentTestObject.h"


@implementation OPPersistentTestObject

@synthesize name;

- (id) initWithName: (NSString*) aName
{
	if (self = [super init]) {
		name = [aName retain];
	}
	return self;
}

- (NSSet*) bunch
{
	return bunch;
}

- (void) addBunchObject: (id) newObject
{
	if (!bunch) {
		bunch = [[OPPersistentSet alloc] init];
	}
	[bunch addObject: newObject];
}

- (void) removeBunchObject: (id) oldObject
{
	[bunch removeObject: oldObject];
}

- (void) dealloc
{
	[name release];
	[bunch release];
	[super dealloc];
}

- (id) initWithCoder: (NSCoder*) coder
{
	name  = [[coder decodeObjectForKey: @"name"] retain];
	bunch = [[coder decodeObjectForKey: @"bunch"] retain];
	return self;
}

- (void) encodeWithCoder: (NSCoder*) coder
{
	[coder encodeObject: name forKey: @"name"];
	[coder encodeObject: bunch forKey: @"bunch"];
}

@end
