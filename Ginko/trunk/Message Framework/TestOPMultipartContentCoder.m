//
//  TestEDMultipartContentCoder.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 02.06.05.
//  Copyright (c) 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "TestOPMultipartContentCoder.h"
#import "OPMBoxFile.h"
#import "NSData+MessageUtils.h"
#import "GIMessage.h"
#import "OPInternetMessage.h"
#import "NSManagedObjectContext+Extensions.h"

@implementation TestOPMultipartContentCoder

- (void)tearDown
{
    [[NSManagedObjectContext threadContext] rollback];
}

- (void)testAttributedString
{
    // read message from resources:
    OPMBoxFile *mboxFile;
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    mboxFile = [OPMBoxFile mboxWithPath:[[NSBundle bundleForClass:[self class]] pathForResource:@"multipartAlternativeTest-mbox" ofType:@"txt"]];
    STAssertTrue(mboxFile != nil, @"mbox could not be read from resources.");
    NSEnumerator *enumerator = [mboxFile messageDataEnumerator];
    NSData *transferData = [[enumerator nextObject] transferDataFromMboxData];
    STAssertTrue(transferData != nil, @"transferData could not be enumerated.");
    GIMessage *message = [GIMessage messageForMessageId:[[[[OPInternetMessage alloc] initWithTransferData:transferData] autorelease] messageId]];
    
    if (!message)
    {
        message = [GIMessage messageWithTransferData:transferData];
    }
    
    STAssertTrue([message messageId] != nil, @"message should have an message id.");

    NSAttributedString *theAttributedString = [message contentAsAttributedString];
    STAssertTrue(theAttributedString != nil, @"message should have an message id.");

    //NSString *thePlainString = [theAttributedString string];
    
    //NSLog(@"thePlainString = %@", thePlainString);
    [pool release];
}

@end
