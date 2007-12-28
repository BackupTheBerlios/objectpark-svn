//
//  TestURLString.m
//  Gina
//
//  Created by Axel Katerbau on 28.12.07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "TestURLString.h"
#import "OPPersistentTestObject.h"

@implementation TestURLString

- (void)testURLString
{
	OPPersistentTestObject *object = [[[OPPersistentTestObject alloc] init] autorelease];
	[context insertObject:object];
	NSString *urlString = [object objectURLString];
	id object1 = [context objectWithURLString:urlString];
	
	NSAssert(object == object1, @"Found different/no object for URL string.");
}

@end
