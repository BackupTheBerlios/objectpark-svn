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

@implementation TestGIThread

- (void)setUp
{
	[OPPersistentObjectContext setDefaultContext:nil];
	OPPersistentObjectContext *context = [[OPPersistentObjectContext alloc] init];
	[OPPersistentObjectContext setDefaultContext: context];
	[[NSFileManager defaultManager] removeFileAtPath: @"/tmp/persistent-testobjects.btrees" handler: nil];
	[context setDatabaseFromPath: @"/tmp/persistent-testobjects.btrees"];
}

- (void)testThreadMessageRelationship
{
	GIMessage *message = [TestGIMessage messageForTest];
	GIThread *thread = [[[GIThread alloc] init] autorelease];
	
	message.thread = thread;
	STAssertEqualObjects(message.thread, thread, @"couldn't set thread in message");

	thread = [GIThread threadForMessage:message];
	NSAssert(thread != nil, @"couldn't get thread for message");
	
	NSAssert([[thread messages] indexOfObject:message] != NSNotFound, @"thread doesn't contain message");
	STAssertEqualObjects(message.thread, thread, @"wrong thread in message");
}

@end
