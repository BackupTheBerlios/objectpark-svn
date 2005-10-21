//
//  TestGIFulltextIndexCenter.m
//  GinkoVoyager
//
//  Created by Ulf Licht on 14.05.05.
//  Copyright (c) 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "TestGIFulltextIndexCenter.h"
#import "GIMessageBase.h"
#import "GIMessageGroup.h"
#import "GIThread.h"
#import "GIFulltextIndexCenter.h"
#import "GIMessage.h"
#import "OPPersistentObject+Extensions.h"

@implementation TestGIFulltextIndexCenter

GIMessage* tempMessage;
NSMutableArray* tempMessageArray;

- (void) setUp
{
    NSLog(@"-[TestGIFulltextIndexCenter setUp]");
    int maxTestMessageCount = 100;
    tempMessageArray = [NSMutableArray arrayWithCapacity:maxTestMessageCount];
    [tempMessageArray retain];
    int i;
    // create test message array
    for (i=0; i<maxTestMessageCount; i++) {
        // create test GIMessage
        NSString *messageId = [NSString stringWithFormat: @"<searchtest-message-%d>",i];
        NSString *transferString = [NSString stringWithFormat:
                                                 @"Message-ID: %@\r\nDate: Fri, 16 Nov 2001 09:51:25 +0100\r\nFrom: Laurent.Julliard@xrce.xerox.com (Laurent Julliard)\r\nMIME-Version: 1.0\r\nSubject: Re: GWorkspace - next steps\r\nReferences: <Pine.LNX.4.33.0111151839560.23892-100000@bla.com\r\nContent-Type: text/plain; charset=us-ascii\r\nContent-Transfer-Encoding: 7bit\r\nNewsgroups: gnu.gnustep.discuss\r\n\r\nUlf Licht wrote:\r\n", messageId];
        NSData *transferData = [transferString dataUsingEncoding:NSASCIIStringEncoding];
        STAssertNotNil(transferData, @"nee");
        
        GIMessage* tempMessageForArray = [GIMessage messageWithTransferData:transferData];
        STAssertNotNil(tempMessageForArray, @"nee %@", messageId);
        STAssertTrue([[tempMessageForArray messageId] isEqual:messageId], @"nee");
        //[tempMessage retain]; // will be retained by NSArray
        [tempMessageArray addObject:tempMessageForArray];
    }
    
    // create test GIMessage
    NSString *messageId = @"<searchtest-message>";
    NSString *transferString = [NSString stringWithFormat:
                                             @"Message-ID: %@\r\nDate: Fri, 16 Nov 2001 09:51:25 +0100\r\nFrom: Laurent.Julliard@xrce.xerox.com (Laurent Julliard)\r\nMIME-Version: 1.0\r\nSubject: Re: GWorkspace - next steps\r\nReferences: <Pine.LNX.4.33.0111151839560.23892-100000@bla.com\r\nContent-Type: text/plain; charset=us-ascii\r\nContent-Transfer-Encoding: 7bit\r\nNewsgroups: gnu.gnustep.discuss\r\n\r\nUlf Licht wrote:\r\n", messageId];
    NSData *transferData = [transferString dataUsingEncoding:NSASCIIStringEncoding];
    STAssertNotNil(transferData, @"nee");
    
    tempMessage = [GIMessage messageWithTransferData:transferData];
    [tempMessage retain];
    STAssertNotNil(tempMessage, @"nee %@", messageId);

    //[tempMessage setValue:messageId forKey: @"messageId"];  
    STAssertTrue([[tempMessage messageId] isEqual:messageId], @"nee");
}

- (void) tearDown
{
    NSLog(@"-[TestGIFulltextIndexCenter tearDown]");
    [tempMessage release];
    [tempMessageArray release];
    [[OPPersistentObjectContext threadContext] revertChanges];
    //[tempIndexCenter release];
}

- (void) testAddMessage
{
    NSLog(@"-[TestGIFulltextIndexCenter testAddOneMessage]");
    //NSLog(@"adding message '%@' with text: %@", [tempMessage messageId], [[tempMessage contentAsAttributedString] string]);
    STAssertTrue([[GIFulltextIndexCenter defaultIndexCenter] addMessage:tempMessage], @"addMessage must return true");
    STAssertTrue([tempMessage hasFlags:OPFulltextIndexedStatus],@"tempMessage must have status OPFulltextIndexedStatus after adding");
    //STAssertTrue([tempIndexCenter flushIndex],@"[tempIndexCenter flushIndex] must return true");
}

- (void) testAddTwoMessages
{
    NSLog(@"-[TestGIFulltextIndexCenter testAddTwoMessages]");
    //NSLog(@"adding message '%@' with text: %@", [tempMessage messageId], [[tempMessage contentAsAttributedString] string]);
    STAssertTrue([[GIFulltextIndexCenter defaultIndexCenter] addMessage:tempMessage], @"addMessage must return true");
    STAssertTrue([tempMessage hasFlags:OPFulltextIndexedStatus],@"tempMessage must have status OPFulltextIndexedStatus after adding");
    //STAssertTrue([tempIndexCenter flushIndex],@"[tempIndexCenter flushIndex] must return true");
    STAssertTrue([[GIFulltextIndexCenter defaultIndexCenter] addMessage:tempMessage], @"addMessage must return true");
    STAssertTrue([tempMessage hasFlags:OPFulltextIndexedStatus],@"tempMessage must have status OPFulltextIndexedStatus after adding");
}

- (void) testAddManyMessages
{
    NSLog(@"-[TestGIFulltextIndexCenter testAddManyMessages]");
    //int i;
    NSEnumerator * messageEnumerator = [tempMessageArray objectEnumerator];
    GIMessage * tempMessageFromArray;
    while ( tempMessageFromArray = [messageEnumerator nextObject] ) {
        STAssertTrue([[GIFulltextIndexCenter defaultIndexCenter] addMessage:tempMessageFromArray], @"addMessage must return true");
        STAssertTrue([tempMessageFromArray hasFlags:OPFulltextIndexedStatus],@"tempMessage must have status OPFulltextIndexedStatus after adding");
    }
}

/*
- (void) testReindexAllMessages
{
    NSLog(@"-[TestGIFulltextIndexCenter reindexAllMessages]");
    STAssertTrue([tempIndexCenter reindexAllMessages],@"[tempIndexCenter reindexAllMessages] must return true");
}
*/

- (void) testSearch
{
    NSLog(@"-[TestGIFulltextIndexCenter testSearch]");
    STAssertTrue( 1 <= [[[GIFulltextIndexCenter defaultIndexCenter] hitsForQueryString: @"Ulf Licht"] count], @"search did not result in one hit");
}

- (void) testXRemoveMessage
{
    NSLog(@"-[TestGIFulltextIndexCenter testXRemoveMessage]");
    STAssertTrue([[GIFulltextIndexCenter defaultIndexCenter] removeMessage:tempMessage],@"removeMessage must return true");
    STAssertFalse([tempMessage hasFlags:OPFulltextIndexedStatus],@"tempMessage must not have status OPFulltextIndexedStatus after removing from index");
}

@end
