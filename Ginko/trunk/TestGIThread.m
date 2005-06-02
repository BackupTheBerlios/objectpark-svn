//
//  TestGIThread.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 24.05.05.
//  Copyright (c) 2005 __MyCompanyName__. All rights reserved.
//

#import "TestGIThread.h"
#import "G3Thread.h"
#import "G3Message.h"
#import "G3MessageGroup.h"
#import "OPMBoxFile.h"
#import "NSManagedObjectContext+Extensions.h"

@implementation TestGIThread

- (void)tearDown
{
    [[NSManagedObjectContext defaultContext] rollback];
}

- (G3Message *)makeAMessage
{
    static int i = 1;
    NSString *messageId = [NSString stringWithFormat:@"<threadtest-message-%d@test.org>",i++];
    NSString *transferString = [NSString stringWithFormat:
                                             @"Message-ID: %@\r\nDate: Fri, 16 Nov 2001 09:51:25 +0100\r\nFrom: Laurent.Julliard@xrce.xerox.com (Laurent Julliard)\r\nMIME-Version: 1.0\r\nSubject: Re: GWorkspace - next steps\r\nReferences: <Pine.LNX.4.33.0111151839560.23892-100000@bla.com\r\nContent-Type: text/plain; charset=us-ascii\r\nContent-Transfer-Encoding: 7bit\r\nNewsgroups: gnu.gnustep.discuss\r\n\r\nUlf Licht wrote:\r\n", messageId];
    NSData *transferData = [transferString dataUsingEncoding:NSASCIIStringEncoding];
    STAssertNotNil(transferData, @"nee");
    
    G3Message *message = [G3Message messageWithTransferData:transferData];
    STAssertNotNil(message, @"nee %@", messageId);
    STAssertTrue([[message messageId] isEqual:messageId], @"nee");
    
    return message;
}

- (void)testSplit
{
    G3Thread *threadA = [[[G3Thread alloc] init] autorelease];
    G3Message *messageA = [self makeAMessage];
    G3Message *messageB = [self makeAMessage];
    G3Message *messageC = [self makeAMessage];
    
    [messageC setValue:messageB forKey:@"reference"];
    
    [threadA addMessage:messageA];
    [threadA addMessage:messageB];
    [threadA addMessage:messageC];
        
    STAssertTrue([[threadA messages] count] == 3, @"not %d", [[threadA messages] count]);
    
    G3Thread *threadB = [threadA splitWithMessage:messageB];
    
    STAssertTrue([[threadA messages] count] == 1, @"not %d", [[threadA messages] count]);
    STAssertTrue([[threadB messages] count] == 2, @"not %d", [[threadB messages] count]);
}

- (void)testMerge
{
    G3Thread *threadA = [[[G3Thread alloc] init] autorelease];
    G3Thread *threadB = [[[G3Thread alloc] init] autorelease];
    G3Message *messageA = [self makeAMessage];
    G3Message *messageB = [self makeAMessage];
    G3Message *messageC = [self makeAMessage];
    
    [messageC setValue:messageB forKey:@"reference"];
    
    [threadB addMessage:messageA];
    [threadB addMessage:messageB];
    [threadA addMessage:messageC];
    
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

- (void)disabledtestGroupAdding
{
    G3Thread *threadA = [NSEntityDescription insertNewObjectForEntityForName:@"G3Thread" inManagedObjectContext:[NSManagedObjectContext defaultContext]];
    G3Message *messageA = [self makeAMessage];
    G3MessageGroup *group = [NSEntityDescription insertNewObjectForEntityForName:@"G3MessageGroup" inManagedObjectContext:[NSManagedObjectContext defaultContext]];
    
    [threadA addMessage:messageA];
    [threadA addGroup:group];
    
    STAssertTrue([[threadA valueForKey:@"groups"] containsObject:group], @"should contain group.");
    STAssertTrue([[group valueForKey:@"threads"] containsObject:threadA], @"should contain thread.");
}

@end
