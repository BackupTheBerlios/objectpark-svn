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
#import "GIMessage.h"
#import "OPPersistentObjectContext.h"
#import "GIMessageBase.h"

@implementation TestGIThread

+ (GIThread *)threadForTest
{
	GIMessage *message = [TestGIMessage messageForTest];
	GIThread *thread = [[[GIThread alloc] init] autorelease];
	
	message.thread = thread;
	NSAssert(message.thread == thread, @"couldn't set thread in message");
	
	thread = [GIThread threadForMessage:message];
	NSAssert(thread != nil, @"couldn't get thread for message");
	
	NSAssert([[thread messages] indexOfObject:message] != NSNotFound, @"thread doesn't contain message");
	NSAssert(message.thread == thread, @"wrong thread in message");
	
	return thread;
}

- (void)testThreadMessageRelationship
{
	[[self class] threadForTest];
}

// WARNING: It is important to have Gina's database deleted before this test really works!
- (void)testThreading
{
	NSString *mboxPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"ThreadingTest" ofType:@"mbox"];
	OPPersistentObjectContext *context = [OPPersistentObjectContext defaultContext];
	
	[context importMboxFiles:[NSArray arrayWithObject:mboxPath] moveOnSuccess:NO];
	GIMessage *msg1 = [context messageForMessageId:@"<id1@test.com>"];
	NSAssert(msg1 != nil, @"could not find message 1");
	GIMessage *msg2 = [context messageForMessageId:@"<id2@test.com>"];
	NSAssert(msg2 != nil, @"could not find message 2");
	
	NSAssert1([[msg2 reference] isEqual:msg1], @"reference is not not set on import, got %@ as reference instead.", [msg2 reference]);
	NSAssert2([msg2 reference] == msg1, @"not correctly threaded (reference is %@. should be %@)", [msg2 reference], msg1);
}

@end
