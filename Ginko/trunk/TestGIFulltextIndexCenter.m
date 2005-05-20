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

- (void)setUp
{
    // get defaultIndexCenter
    NSLog(@"-[TestGIFulltextIndexCenter setUp]");
    tempIndexCenter = [GIFulltextIndexCenter defaultIndexCenter];
}

- (void)tearDown
{
}

- (void)testAddOneMessage
/*" Caution: Does not pass if the default message group has no messages in it. "*/
{
    NSLog(@"-[TestGIFulltextIndexCenter testAddMessage]");
    
    G3MessageGroup* tempMessageGroup = [G3MessageGroup defaultMessageGroup];
    STAssertNotNil(tempMessageGroup, @"tempMessageGroup must not be NIL");
    
    // get all threads
    NSArray* tempAllThreads = [tempMessageGroup threadsByDate];
    
    // work with first thread of MessageGroup
    STAssertTrue([tempAllThreads count] > 0, @"At least one thread must be given in MessageGroup '%@'", [tempMessageGroup name]);
    G3Thread* tempThread = (G3Thread*)[tempAllThreads objectAtIndex:0];
    
    // add first message of a thread to the index
    STAssertTrue([[tempThread messagesByDate] count] > 0, @"At least one message must be given");
    G3Message* tempMessage = (G3Message*)[[tempThread messagesByDate] objectAtIndex:0];
    NSLog(@"adding message with text: %@", [[tempMessage contentAsAttributedString] string]);
    BOOL addMessageResult = [tempIndexCenter addMessage:tempMessage];
    
    // assert that indexing was successfull
    STAssertTrue(addMessageResult,@"addMessage must return TRUE");
    STAssertTrue([tempMessage hasFlag:OPFulltextIndexedStatus],@"tempMessage must have status OPFulltextIndexedStatus after adding");
}

- (void)testSearch
{
    NSLog(@"-[TestGIFulltextIndexCenter testSearch]");
    [tempIndexCenter hitsForQueryString:@"feedback"];
}

@end
