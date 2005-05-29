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
    //[tempIndexCenter retain];
    STAssertNotNil(tempIndexCenter, @"tempIndexCenter must not be nil");
    
    NSLog(@"created tempIndexCenter");
       
    NSString *messageId = @"<searchtest-message-1>";
    NSString *transferString = [NSString stringWithFormat:
                                             @"Message-ID: %@\r\nDate: Fri, 16 Nov 2001 09:51:25 +0100\r\nFrom: Laurent.Julliard@xrce.xerox.com (Laurent Julliard)\r\nMIME-Version: 1.0\r\nSubject: Re: GWorkspace - next steps\r\nReferences: <Pine.LNX.4.33.0111151839560.23892-100000@bla.com\r\nContent-Type: text/plain; charset=us-ascii\r\nContent-Transfer-Encoding: 7bit\r\nNewsgroups: gnu.gnustep.discuss\r\n\r\nUlf Licht wrote:\r\n", messageId];
    NSData *transferData = [transferString dataUsingEncoding:NSASCIIStringEncoding];
    STAssertNotNil(transferData, @"nee");
    
    tempMessage = [G3Message messageWithTransferData:transferData];
    [tempMessage retain];
    STAssertNotNil(tempMessage, @"nee %@", messageId);

    //[tempMessage setValue:messageId forKey:@"messageId"];  
    STAssertTrue([[tempMessage messageId] isEqual:messageId], @"nee");
}

- (void)tearDown
{
    NSLog(@"-[TestGIFulltextIndexCenter tearDown]");
    [tempMessage release];
    //[tempIndexCenter release];
}

- (void)testAddOneMessage
{
    NSLog(@"-[TestGIFulltextIndexCenter testAddOneMessage]");
    //NSLog(@"adding message '%@' with text: %@", [tempMessage messageId], [[tempMessage contentAsAttributedString] string]);
    STAssertTrue([tempIndexCenter addMessage:tempMessage], @"addMessage must return true");
    STAssertTrue([tempMessage hasFlag:OPFulltextIndexedStatus],@"tempMessage must have status OPFulltextIndexedStatus after adding");
    //STAssertTrue([tempIndexCenter flushIndex],@"[tempIndexCenter flushIndex] must return true");
}

/*
- (void)testReindexAllMessages
{
    NSLog(@"-[TestGIFulltextIndexCenter reindexAllMessages]");
    STAssertTrue([tempIndexCenter reindexAllMessages],@"[tempIndexCenter reindexAllMessages] must return true");
}
*/

- (void)testSearch
{
    NSLog(@"-[TestGIFulltextIndexCenter testSearch]");
    STAssertTrue( 1 == [[tempIndexCenter hitsForQueryString:@"Ulf Licht"] count], "search did not result in one hit");
}

- (void)testXRemoveMessage
{
    NSLog(@"-[TestGIFulltextIndexCenter testXRemoveMessage]");
    STAssertTrue([tempIndexCenter removeMessage:tempMessage],@"removeMessage must return true");
    STAssertFalse([tempMessage hasFlag:OPFulltextIndexedStatus],@"tempMessage must not have status OPFulltextIndexedStatus after removing from index");
}

@end
