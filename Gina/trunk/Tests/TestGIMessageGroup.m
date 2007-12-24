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
	
#warning Axel -> Dirk: Don't know how to add threads to groups the right way...
#warning Axel -> Dirk: By the way, we need to dicsuss about how to model the message group hierarchy...we can do better than in Ginko, I think.
//	[group addThreadsObject:thread];
}

@end
