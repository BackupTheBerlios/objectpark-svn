//
//  TestGIMessage.m
//  Gina
//
//  Created by Axel Katerbau on 22.12.07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "TestGIMessage.h"


@implementation TestGIMessage

- (void)testInfrastructure
{
	NSNumber *aNumber = [NSNumber numberWithInt:42];
	NSLog(@"this is a test %@", aNumber);
}

@end
