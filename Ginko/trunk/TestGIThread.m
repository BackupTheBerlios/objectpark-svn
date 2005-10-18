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

- (void) tearDown
{
    [[OPPersistentObjectContext threadContext] revertChanges];
}

- (GIMessage*) makeAMessage
{
    static int i = 1;
    NSString *messageId = [NSString stringWithFormat:@"<threadtest-message-%d@test.org>",i++];
    NSString *transferString = [NSString stringWithFormat:
                                             @"Message-ID: %@\r\nDate: Fri, 16 Nov 2001 09:51:25 +0100\r\nFrom: Laurent.Julliard@xrce.xerox.com (Laurent Julliard)\r\nMIME-Version: 1.0\r\nSubject: Re: GWorkspace - next steps\r\nReferences: <Pine.LNX.4.33.0111151839560.23892-100000@bla.com\r\nContent-Type: text/plain; charset=us-ascii\r\nContent-Transfer-Encoding: 7bit\r\nNewsgroups: gnu.gnustep.discuss\r\n\r\nUlf Licht wrote:\r\n", messageId];
    NSData *transferData = [transferString dataUsingEncoding:NSASCIIStringEncoding];
    STAssertNotNil(transferData, @"nee");
    
    GIMessage *message = [GIMessage messageWithTransferData:transferData];
    STAssertNotNil(message, @"nee %@", messageId);
    STAssertTrue([[message messageId] isEqual:messageId], @"nee");
    
    return message;
}

- (void) testSplit
{
    GIThread *threadA = [[[GIThread alloc] init] autorelease];
    GIMessage *messageA = [self makeAMessage];
    GIMessage *messageB = [self makeAMessage];
    GIMessage *messageC = [self makeAMessage];
    
    [messageC setValue:messageB forKey:@"reference"];
    
    [threadA addToMessages: messageA];
    [threadA addToMessages: messageB];
    [threadA addToMessages: messageC];
        
    STAssertTrue([[threadA messages] count] == 3, @"not %d", [[threadA messages] count]);
    
    GIThread *threadB = [threadA splitWithMessage:messageB];
    
    STAssertTrue([[threadA messages] count] == 1, @"not %d", [[threadA messages] count]);
    STAssertTrue([[threadB messages] count] == 2, @"not %d", [[threadB messages] count]);
}

- (void) testMerge
{
    GIThread *threadA = [[[GIThread alloc] init] autorelease];
    GIThread *threadB = [[[GIThread alloc] init] autorelease];
    GIMessage *messageA = [self makeAMessage];
    GIMessage *messageB = [self makeAMessage];
    GIMessage *messageC = [self makeAMessage];
    
    [messageC setValue:messageB forKey:@"reference"];
    
    [threadB addToMessages: messageA];
    [threadB addToMessages: messageB];
    [threadA addToMessages: messageC];
    
    STAssertTrue([[threadA messages] count] == 1, @"not %d", [[threadA messages] count]);
    STAssertTrue([[threadB messages] count] == 2, @"not %d", [[threadB messages] count]);
    
    id groupsFromThreadB = [threadB valueForKey:@"groups"];
    
    [threadA mergeMessagesFromThread:threadB];
    
    STAssertTrue([[threadA messages] count] == 3, @"not %d", [[threadA messages] count]);
    
    NSEnumerator *enumerator = [groupsFromThreadB objectEnumerator];
    NSArray *threads;
    while (threads = [[enumerator nextObject] objectForKey:@"threads"])
    {
        STAssertTrue(![threads containsObject:threadB], @"Should not contain %@", threadB);
    }
}

- (void) disabledtestGroupAdding
{
    /*
    GIThread *threadA = [NSEntityDescription insertNewObjectForEntityForName:@"GIThread" inManagedObjectContext:[OPPersistentObjectContext threadContext]];
    GIMessage *messageA = [self makeAMessage];
    GIMessageGroup *group = [NSEntityDescription insertNewObjectForEntityForName:@"GIMessageGroup" inManagedObjectContext:[OPPersistentObjectContext threadContext]];
    
    [threadA addToMessages: messageA];
    [threadA addToGroups: group];
    
    STAssertTrue([[threadA valueForKey: @"groups"] containsObject: group], @"should contain group.");
    STAssertTrue([[group valueForKey: @"threads"] containsObject: threadA], @"should contain thread.");
     */
}

@end
