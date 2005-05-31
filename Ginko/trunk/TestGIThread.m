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

- (G3Message *)makeAMessageWithId:(NSString *)messageId
{
    G3Message *result;
    
    NSString *transferString = [NSString stringWithFormat:
    @"Message-ID: %@\r\nDate: Fri, 16 Nov 2001 09:51:25 +0100\r\nFrom: Laurent.Julliard@xrce.xerox.com (Laurent Julliard)\r\nMIME-Version: 1.0\r\nSubject: Re: GWorkspace - next steps\r\nReferences: <Pine.LNX.4.33.0111151839560.23892-100000@bla.com\r\nContent-Type: text/plain; charset=us-ascii\r\nContent-Transfer-Encoding: 7bit\r\nNewsgroups: gnu.gnustep.discuss\r\n\r\nLudovic Marcotte wrote:\r\n", messageId];
    
    NSData *transferData = [transferString dataUsingEncoding:NSASCIIStringEncoding];
    
    STAssertNotNil(transferData, @"nee");
    
    result = [G3Message messageWithTransferData:transferData];
    [result setValue:messageId forKey:@"messageId"];  

    STAssertNotNil(result, @"nee %@", messageId);
    STAssertTrue([[result messageId] isEqual:messageId], @"nee");
    
    return result;
}

- (void)testSplit
{
    G3Thread *threadA = [[[G3Thread alloc] init] autorelease];
    G3Message *messageA = [self makeAMessageWithId:@"test1"];
    G3Message *messageB = [self makeAMessageWithId:@"test2"];
    G3Message *messageC = [self makeAMessageWithId:@"test3"];
    
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
    G3Message *messageA = [self makeAMessageWithId:@"testA"];
    G3Message *messageB = [self makeAMessageWithId:@"testB"];
    G3Message *messageC = [self makeAMessageWithId:@"testC"];
    
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

- (void)testGroupAdding
{
    G3Thread *threadA = [[[G3Thread alloc] init] autorelease];
    G3Message *messageA = [self makeAMessageWithId:@"testA1"];
    G3MessageGroup *group = [G3MessageGroup defaultMessageGroup];
    
    [threadA addMessage:messageA];
    [threadA addGroup:group];
    
    STAssertTrue([[threadA valueForKey:@"groups"] containsObject:group], @"should contain group.");
    STAssertTrue([[group valueForKey:@"threads"] containsObject:threadA], @"should contain thread.");
}

@end
