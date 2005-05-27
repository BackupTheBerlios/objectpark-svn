//
//  TestGIFulltextIndexCenter.m
//  GinkoVoyager
//
//  Created by Ulf Licht on 14.05.05.
//  Copyright (c) 2005 __MyCompanyName__. All rights reserved.
//

#import "TestGIFulltextIndexCenter.h"
#import "GIMessageBase.h"
#import "G3MessageGroup.h"
#import "G3Thread.h"
#import "GIFulltextIndexCenter.h"
#import "G3Message.h"


@implementation TestGIFulltextIndexCenter

GIFulltextIndexCenter* tempIndexCenter;
G3Message* tempMessage;

- (void)setUp
{
    // get defaultIndexCenter
    NSLog(@"-[TestGIFulltextIndexCenter setUp]");
    tempIndexCenter = [GIFulltextIndexCenter defaultIndexCenter];

#pragma mark Hier knallt es schon, weil der index nicht gešffnet/angelegt werden konnte!
    
    NSLog(@"created tempIndexCenter");
    
    // get first message of default mailbox
    G3MessageGroup* tempMessageGroup = [G3MessageGroup defaultMessageGroup];
    STAssertNotNil(tempMessageGroup, @"tempMessageGroup must not be NIL");
    
    // get all threads
    NSArray* tempAllThreads = [tempMessageGroup threadsByDate];
    
    // work with first thread of MessageGroup
    STAssertTrue([tempAllThreads count] > 0, @"At least one thread must be given in MessageGroup to run fulltext search tests '%@'", [tempMessageGroup name]);
    G3Thread* tempThread = (G3Thread*)[tempAllThreads objectAtIndex:0];
    
    // get first message of a thread
    STAssertTrue([[tempThread messagesByDate] count] > 0, @"At least one message must be given to run fulltext search tests");
    tempMessage = (G3Message*)[[tempThread messagesByDate] objectAtIndex:0];
}

- (void)tearDown
{
}

- (void)testAddOneMessage
{
    #warning Does not pass if the default message group has no messages in it.
    NSLog(@"-[TestGIFulltextIndexCenter testAddOneMessage]");
    //NSLog(@"adding message '%@' with text: %@", [tempMessage messageId], [[tempMessage contentAsAttributedString] string]);
    STAssertTrue([tempIndexCenter addMessage:tempMessage], @"addMessage must return true");
    STAssertTrue([tempMessage hasFlag:OPFulltextIndexedStatus],@"tempMessage must have status OPFulltextIndexedStatus after adding");
    //STAssertTrue([tempIndexCenter flushIndex],@"[tempIndexCenter flushIndex] must return true");
}

/*
- (void)reindexAllMessages
{
    NSLog(@"-[TestGIFulltextIndexCenter reindexAllMessages]");
    STAssertTrue([tempIndexCenter reindexAllMessages],@"[tempIndexCenter reindexAllMessages] must return true");
    STAssertTrue([tempIndexCenter flushIndex],@"[tempIndexCenter flushIndex] must return true");
}
*/

- (void)testSearch
{
    NSLog(@"-[TestGIFulltextIndexCenter testSearch]");
    [tempIndexCenter hitsForQueryString:@"pasteboard"];
}

- (void)testXRemoveMessage
{
    NSLog(@"-[TestGIFulltextIndexCenter testXRemoveMessage]");
    STAssertTrue([tempIndexCenter removeMessage:tempMessage],@"removeMessage must return true");
    STAssertFalse([tempMessage hasFlag:OPFulltextIndexedStatus],@"tempMessage must not have status OPFulltextIndexedStatus after removing from index");
}

@end
