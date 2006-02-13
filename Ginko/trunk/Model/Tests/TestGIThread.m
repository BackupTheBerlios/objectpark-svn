//
//  TestGIThread.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 24.05.05.
//  Copyright (c) 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "TestGIThread.h"
#import "GIThread.h"
#import "GIMessage.h"
#import "GIMessageGroup.h"
#import "OPMBoxFile.h"
#import "OPPersistentObject+Extensions.h"

@implementation TestGIThread

#pragma mark Helper
- (GIMessage*) makeMessageWithId:(NSString*)messageId andReferences:(NSString*)references
{
    NSString *transferString;
    if (references)
        transferString = [NSString stringWithFormat:@"Message-ID: %@\r\nReferences: %@\r\n\r\nbody\r\n", messageId, references];
    else
        transferString = [NSString stringWithFormat:@"Message-ID: %@\r\n\r\nbody\r\n", messageId];
        
    NSData *transferData = [transferString dataUsingEncoding:NSASCIIStringEncoding];
    STAssertNotNil(transferData, @"Could not create the transfer data for message with id %@ and references %@", messageId, references);
    
    GIMessage *message = [GIMessage messageWithTransferData:transferData];
    STAssertNotNil(message, @"Could not create message for id %@ from transfer data %@", messageId, transferData);
    STAssertTrue([[message messageId] isEqual:messageId], @"Message has a wrong message id");
    
    return message;
}


- (GIMessage*) makeAMessage
{
    static int i = 1;
    NSString *messageId = [NSString stringWithFormat: @"<threadtest-message-%d@test.org>",i++];
    
    return [self makeMessageWithId:messageId andReferences:nil];
}


#pragma mark Tests

/* tested api no longer exists
- (void) testSplit
{
    GIThread* threadA = [[[GIThread alloc] init] autorelease];
    GIMessage* messageA = [self makeAMessage];
    GIMessage* messageB = [self makeAMessage];
    GIMessage* messageC = [self makeAMessage];
    
    [messageC setValue: messageB forKey: @"reference"];
    
    [threadA addValue: messageA forKey: @"messages"];
    [threadA addValue: messageB forKey: @"messages"];
    [threadA addValue: messageC forKey: @"messages"];
        
    STAssertTrue([[threadA messages] count] == 3, @"not %d", [[threadA messages] count]);
    
    GIThread* threadB = [threadA splitWithMessage: messageB];
    
    STAssertTrue([[threadA messages] count] == 1, @"not %d", [[threadA messages] count]);
    STAssertTrue([[threadB messages] count] == 2, @"not %d", [[threadB messages] count]);
}
*/


- (void) testMerge
{
    GIThread *threadA = [[[GIThread alloc] init] autorelease];
    GIThread *threadB = [[[GIThread alloc] init] autorelease];
    GIMessage *messageA = [self makeAMessage];
    GIMessage *messageB = [self makeAMessage];
    GIMessage *messageC = [self makeAMessage];
    
    [messageC setValue:messageB forKey: @"reference"];
    
    [threadB addValue: messageA forKey: @"messages"];
    [threadB addValue: messageB forKey: @"messages"];
    [threadA addValue: messageC forKey: @"messages"];
    
    STAssertTrue([[threadA messages] count] == 1, @"not %d", [[threadA messages] count]);
    STAssertTrue([[threadB messages] count] == 2, @"not %d", [[threadB messages] count]);
    
    id groupsFromThreadB = [threadB valueForKey: @"groups"];
    
    [threadA mergeMessagesFromThread:threadB];
    
    STAssertTrue([[threadA messages] count] == 3, @"not %d", [[threadA messages] count]);
    
    NSEnumerator* enumerator = [groupsFromThreadB objectEnumerator];
    NSArray* threads;
    while (threads = [[enumerator nextObject] objectForKey: @"threads"])
    {
        STAssertTrue(![threads containsObject: threadB], @"Should not contain %@", threadB);
    }
}


- (void) disabledtestGroupAdding
{
    /*
    GIThread *threadA = [NSEntityDescription insertNewObjectForEntityForName: @"GIThread" inManagedObjectContext:[OPPersistentObjectContext threadContext]];
    GIMessage *messageA = [self makeAMessage];
    GIMessageGroup *group = [NSEntityDescription insertNewObjectForEntityForName: @"GIMessageGroup" inManagedObjectContext:[OPPersistentObjectContext threadContext]];
    
    [threadA addToMessages: messageA];
    [threadA addToGroups: group];
    
    STAssertTrue([[threadA valueForKey: @"groups"] containsObject: group], @"should contain group.");
    STAssertTrue([[group valueForKey: @"threads"] containsObject: threadA], @"should contain thread.");
     */
}


#pragma mark tests for +threadForMessage:
- (void) testThreadForMessage_returnExistingThread
{
    GIMessage* message = [self makeMessageWithId:@"<1>" andReferences:nil];
    STAssertNotNil(message, @"Creating message without references failed");
    
    GIThread* thread = [[[GIThread alloc] init] autorelease];
    STAssertNotNil(thread, @"Creating a thread failed");
    
    [thread addMessage:message];
    STAssertNotNil([message thread], @"Could not add the test message to the test thread");
    
    
    GIThread *threadForMessage = [GIThread threadForMessage:message];
    STAssertNotNil(threadForMessage, @"+threadForMessage did not return a thread");
    STAssertEqualObjects(thread, threadForMessage, @"+threadForMessage returned a wrong thread");
}


- (void) testThreadForMessage_returnNewThread
{
    GIMessage* message = [self makeMessageWithId:@"<1>" andReferences:nil];
    STAssertNotNil(message, @"Creating message without references failed");
    
    NSAssert([message thread] == nil, @"Test message erroneously has a thread!");
    
    
    GIThread *thread = [GIThread threadForMessage:message];
    STAssertNotNil(thread, @"+threadForMessage did not return a thread");
}


#pragma mark tests for +addMessageToAppropriateThread:
- (void) testAddMessageToAppropriateThread_newThreadWithOnlyTheMessage
{
    GIMessage* message = [self makeMessageWithId:@"<3>" andReferences:nil];
    STAssertNotNil(message, @"Creating test message failed");
    
    
    [GIThread addMessageToAppropriateThread:message];
    
    GIThread* thread = [message thread];
    STAssertNotNil(thread, @"Message has no thread!");
    
    NSArray* messages = [thread messages];
    STAssertNotNil(messages, @"Thread of test message has no messages!?!");
    STAssertEquals([messages count], (unsigned)1, @"Thread contains the wrong number of messages (should be 1)");
    STAssertTrue([messages containsObject:message], @"The thread of the test message does not contain the test message");
}


- (void) testAddMessageToAppropriateThread_newThreadWithDummyReferences
{
    GIMessage* message = [self makeMessageWithId:@"<3>" andReferences:@"<1> <2>"];
    STAssertNotNil(message, @"Creating test message failed");
    
    
    [GIThread addMessageToAppropriateThread:message];
    
    GIThread* thread = [message thread];
    STAssertNotNil(thread, @"Message has no thread!");
    
    NSArray* messages = [thread messages];
    STAssertNotNil(messages, @"Thread of test message has no messages!?!");
    STAssertEquals([messages count], (unsigned)3, @"Thread contains the wrong number of messages (should be 3)");
    STAssertTrue([messages containsObject:message], @"The thread of the test message does not contain the test message");
    
    GIMessage* dummyMsg2 = [GIMessage messageForMessageId:@"<2>"];
    STAssertNotNil(dummyMsg2, @"Message for reference <2> does not exist");
    STAssertTrue([dummyMsg2 isDummy], @"Message for reference <2> is not a dummy message");
    STAssertTrue([messages containsObject:dummyMsg2], @"Message for reference <2> is not in the thread");
    
    GIMessage* dummyMsg1 = [GIMessage messageForMessageId:@"<1>"];
    STAssertNotNil(dummyMsg1, @"Message for reference <1> does not exist");
    STAssertTrue([dummyMsg1 isDummy], @"Message for reference <1> is not a dummy message");
    STAssertTrue([messages containsObject:dummyMsg1], @"Message for reference <1> is not in the thread");
    
    // check reference connections
    GIMessage* msgRef = [message reference];
    STAssertEqualObjects(msgRef, dummyMsg2, @"Reference of test message is wrong (should be %@", dummyMsg2);
    GIMessage* dummy2Ref = [dummyMsg2 reference];
    STAssertEqualObjects(dummy2Ref, dummyMsg1, @"Reference of test message is wrong (should be %@", dummyMsg1);
    NSAssert([dummyMsg1 reference] == nil, @"Root message has a reference!");
}


- (void) testAddMessageToAppropriateThread_addToExistingThread
{
    GIMessage* root = [self makeMessageWithId:@"<1>" andReferences:@"<0>"];
    STAssertNotNil(root, @"Creating test root message failed");
    
    GIThread* thread = [GIThread threadForMessage:root];
    STAssertNotNil(thread, @"Root message has no thread");
    STAssertEquals([[thread messages] count], (unsigned)1, @"The thread of the root message contains more than 1 message");
    NSAssert([root reference] == nil, @"The root message has a reference to a non existing message");
    
    GIMessage* message = [self makeMessageWithId:@"<2>" andReferences:@"<1>"];
    STAssertNotNil(message, @"Creating test message failed");
    
    
    [GIThread addMessageToAppropriateThread:message];
    
    GIThread *threadForMessage = [GIThread threadForMessage:message];
    STAssertEqualObjects(threadForMessage, thread, @"Message is not in the same thread as the root message");
    
    NSArray* messages = [thread messages];
    STAssertEquals([messages count], (unsigned)2, @"The thread of the root message contains the wrong number of messages (should be 2)");
    STAssertTrue([messages containsObject:root], @"Root message is not in the thread");
    STAssertTrue([messages containsObject:message], @"Message is not in the thread");
    STAssertEqualObjects([message reference], root, @"The message has no reference to the root message");
    NSAssert([root reference] == nil, @"The root message has a reference!");
}


- (void) testAddMessageToAppropriateThread_addToExistingThreadWithDummies
{
    GIMessage* root = [self makeMessageWithId:@"<1>" andReferences:nil];
    STAssertNotNil(root, @"Creating test root message failed");
    
    GIThread* thread = [GIThread threadForMessage:root];
    STAssertNotNil(thread, @"Root message has no thread");
    
    GIMessage* message = [self makeMessageWithId:@"<3>" andReferences:@"<1> <2>"];
    STAssertNotNil(message, @"Creating test message failed");
    
    
    [GIThread addMessageToAppropriateThread:message];
    
    GIThread *threadForMessage = [GIThread threadForMessage:message];
    STAssertEqualObjects(threadForMessage, thread, @"Message is not in the same thread as the root message");
    
    GIMessage* dummy = [GIMessage messageForMessageId:@"<2>"];
    STAssertNotNil(dummy, @"The dummy message which links the message to the root does not exist");
    
    NSArray* messages = [thread messages];
    STAssertEquals([messages count], (unsigned)3, @"The thread of the root message contains the wrong number of messages (should be 2)");
    STAssertTrue([messages containsObject:root], @"Root message is not in the thread");
    STAssertTrue([messages containsObject:dummy], @"Dummy message is not in the thread");
    STAssertTrue([messages containsObject:message], @"Message is not in the thread");
    STAssertEqualObjects([message reference], dummy, @"The message has no reference to the dummy message");
    STAssertEqualObjects([dummy reference], root, @"The dummy message has no reference to the root message");
}


- (void) testAddMessageToAppropriateThread_withMessageInReferences
{
    GIMessage* root = [self makeMessageWithId:@"<1>" andReferences:nil];
    STAssertNotNil(root, @"Creating test root message failed");
    
    GIThread* thread = [GIThread threadForMessage:root];
    STAssertNotNil(thread, @"Root message has no thread");
    
    GIMessage* message = [self makeMessageWithId:@"<3>" andReferences:@"<1> <2> <3>"];
    STAssertNotNil(message, @"Creating test message failed");
    
    
    [GIThread addMessageToAppropriateThread:message];
    
    GIThread *threadForMessage = [GIThread threadForMessage:message];
    STAssertEqualObjects(threadForMessage, thread, @"Message is not in the same thread as the root message");
    
    GIMessage* dummy = [GIMessage messageForMessageId:@"<2>"];
    STAssertNotNil(dummy, @"The dummy message which links the message to the root does not exist");
    
    NSArray* messages = [thread messages];
    STAssertEquals([messages count], (unsigned)3, @"The thread of the root message contains the wrong number of messages (should be 2)");
    STAssertTrue([messages containsObject:root], @"Root message is not in the thread");
    STAssertTrue([messages containsObject:dummy], @"Dummy message is not in the thread");
    STAssertTrue([messages containsObject:message], @"Message is not in the thread");
    STAssertEqualObjects([message reference], dummy, @"The message has no reference to the dummy message");
    STAssertEqualObjects([dummy reference], root, @"The dummy message has no reference to the root message");
}


- (void) testAddMessageToAppropriateThread_withDuplicatesInReferences
{
    GIMessage* root = [self makeMessageWithId:@"<1>" andReferences:nil];
    STAssertNotNil(root, @"Creating test root message failed");
    
    GIThread* thread = [GIThread threadForMessage:root];
    STAssertNotNil(thread, @"Root message has no thread");
    
    GIMessage* message = [self makeMessageWithId:@"<3>" andReferences:@"<1> <1> <2> <2>"];
    STAssertNotNil(message, @"Creating test message failed");
    
    
    [GIThread addMessageToAppropriateThread:message];
    
    GIThread *threadForMessage = [GIThread threadForMessage:message];
    STAssertEqualObjects(threadForMessage, thread, @"Message is not in the same thread as the root message");
    
    GIMessage* dummy = [GIMessage messageForMessageId:@"<2>"];
    STAssertNotNil(dummy, @"The dummy message which links the message to the root does not exist");
    
    NSArray* messages = [thread messages];
    STAssertEquals([messages count], (unsigned)3, @"The thread of the root message contains the wrong number of messages (should be 2)");
    STAssertTrue([messages containsObject:root], @"Root message is not in the thread");
    STAssertTrue([messages containsObject:dummy], @"Dummy message is not in the thread");
    STAssertTrue([messages containsObject:message], @"Message is not in the thread");
    STAssertEqualObjects([message reference], dummy, @"The message has no reference to the dummy message");
    STAssertEqualObjects([dummy reference], root, @"The dummy message has no reference to the root message");
}


@end
