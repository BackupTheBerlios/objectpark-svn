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

+ (GIMessage *)messageForTest
{
	NSString *transferDataPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestMIMEBoundaries" ofType:@"transferData"];
	NSAssert(transferDataPath != nil, @"couldn't find transferdata resource");
	
	NSData *transferData = [NSData dataWithContentsOfFile:transferDataPath];
	NSAssert(transferData != nil, @"couldn't read transferdata");
	
	OPInternetMessage *internetMessage = [[[OPInternetMessage alloc] initWithTransferData:transferData] autorelease];
	GIMessage *message = [GIMessage messageWithInternetMessage:internetMessage];
	NSAssert(message != nil, @"couldn't create message from internetMessage");
	
	NSString *subject = message.subject;
	NSAssert([subject isEqualToString:@"strained"], @"wrong subject in message");
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
	[[OPPersistentObjectContext defaultContext] addMessage: message];
	NSAssert(message.thread != nil, @"No thread assigned to message.");
	NSAssert(message.thread.messageGroups.count, @"No group assigned to message thread.");
	NSAssert([GIMessageGroup defaultMessageGroup].threads.count > 0, @"Inverse relationships not set.");
}

@end
