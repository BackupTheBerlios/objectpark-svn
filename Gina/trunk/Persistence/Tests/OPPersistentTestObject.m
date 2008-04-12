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


- (void) dealloc
{
	[name release];
	[super dealloc];
}

- (id) initWithCoder: (NSCoder*) coder
{
	name = [coder decodeObjectForKey: @"name"];
	
	return self;
}

- (void) encodeWithCoder: (NSCoder*) coder
{
	[coder encodeObject: name forKey: @"name"];
}

@end
