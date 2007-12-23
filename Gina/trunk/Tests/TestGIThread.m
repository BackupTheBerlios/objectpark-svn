//
//  TestGIThread.m
//  Gina
//
//  Created by Axel Katerbau on 23.12.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import "TestGIThread.h"
#import "TestGIMessage.h"
#import "GIThread.h"

@implementation TestGIThread

- (void)testThreadMessageRelationship
{
	GIMessage *message = [TestGIMessage messageForTest];
	GIThread *thread = [GIThread threadForMessage:message];
	NSAssert(thread != nil, @"couldn't get thread for message");
}

@end
