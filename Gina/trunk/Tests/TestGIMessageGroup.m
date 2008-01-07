//
//  TestGIMessageGroup.m
//  Gina
//
//  Created by Axel Katerbau on 24.12.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import "TestGIMessageGroup.h"
#import "GIMessageGroup.h"
#import "TestGIThread.h"

@implementation TestGIMessageGroup

- (void)testGroupThreadRelationship
{
	GIMessageGroup *group = [[[GIMessageGroup alloc] init] autorelease];
	GIThread *thread = [TestGIThread threadForTest];
	
//	[group addThreadsObject:thread];
}

@end
