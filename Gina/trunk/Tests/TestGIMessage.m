//
//  TestGIMessage.m
//  Gina
//
//  Created by Axel Katerbau on 22.12.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import "TestGIMessage.h"
#import "GIMessage.h"
#import "GIMessageGroup.h"
#import "GIThread.h"
#import "OPInternetMessage.h"
#import "GIMessageBase.h"

@implementation TestGIMessage

+ (OPInternetMessage*) newInternetMessageForTest
{
	NSString *transferDataPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestMIMEBoundaries" ofType:@"transferData"];
	NSAssert(transferDataPath != nil, @"couldn't find transferdata resource");
	
	NSData *transferData = [NSData dataWithContentsOfFile:transferDataPath];
	NSAssert(transferData != nil, @"couldn't read transferdata");
	
	OPInternetMessage *result = [[OPInternetMessage alloc] initWithTransferData:transferData];
	
	return result;
}

+ (GIMessage *)messageForTest
{
	NSString *transferDataPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestMIMEBoundaries" ofType:@"transferData"];
	NSAssert(transferDataPath != nil, @"couldn't find transferdata resource");
	
	NSData *transferData = [NSData dataWithContentsOfFile:transferDataPath];
	NSAssert(transferData != nil, @"couldn't read transferdata");
	
	OPInternetMessage *internetMessage = [self newInternetMessageForTest];
	GIMessage *message = [GIMessage messageWithInternetMessage: internetMessage appendToAppropriateThread: NO];
	[internetMessage release];
	NSAssert(message != nil, @"couldn't create message from internetMessage");
	
	//NSString *subject = message.subject;
	//NSAssert([subject isEqualToString:@"strained"], @"wrong subject in message");
	return message;
}

- (void)testMessageCreation
{
	[[self class] messageForTest];
}

- (void)testMessageIdIndexPersistence
{
	GIMessage *message = [[self class] messageForTest];
	
	NSString *messageId = [message messageId];
	NSAssert(messageId != nil, @"could not get message id from message");
	
	GIMessage *fetchedMessage = [[OPPersistentObjectContext defaultContext] messageForMessageId:messageId];
	NSAssert(fetchedMessage != nil, @"could not fetch previously created message for message id");
	NSAssert([[fetchedMessage messageId] isEqualToString:messageId], @"message id from fetched message not correct");
}

- (void) testMessageAddition
{
	GIMessage* message = [[self class] messageForTest];
	[[OPPersistentObjectContext defaultContext] insertObject: message];
	NSAssert(message.thread != nil, @"No thread assigned to message.");
	NSAssert(message.thread.messageGroups.count, @"No group assigned to message thread.");
	NSAssert([GIMessageGroup defaultMessageGroup].threads.count > 0, @"Inverse relationships not set.");
}

- (void)testMessageFlags
{
	GIMessage *message = [[self class] messageForTest];
	NSAssert(!message.isSeen, @"message should not be seen");
	[message setIsSeen: YES];
	NSAssert(message.isSeen, @"message should be seen");
}

- (void) testRetains
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	OPInternetMessage* msg = [[self class] newInternetMessageForTest];
	NSDictionary* headerDict = [msg valueForKey: @"headerDictionary"];
	NSDictionary* headerFields = [msg valueForKey: @"headerFields"];
	[pool release];
	NSAssert([headerDict retainCount] == 1, @"Leaking header dict?");
	NSAssert([headerFields retainCount] == 1, @"Leaking header dict?");
	[msg release];
	
}

@end
