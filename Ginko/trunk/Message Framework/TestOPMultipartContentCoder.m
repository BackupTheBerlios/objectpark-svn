//
//  TestEDMultipartContentCoder.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 02.06.05.
//  Copyright (c) 2005 __MyCompanyName__. All rights reserved.
//

#import "TestOPMultipartContentCoder.h"
#import "OPMBoxFile.h"
#import "NSData+MessageUtils.h"
#import "G3Message.h"
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
    G3Message *message = [G3Message messageForMessageId:[[[[OPInternetMessage alloc] initWithTransferData:transferData] autorelease] messageId]];
    
    if (!message)
    {
        message = [G3Message messageWithTransferData:transferData];
    }
    
    STAssertTrue([message messageId] != nil, @"message should have an message id.");

    NSAttributedString *theAttributedString = [message contentAsAttributedString];
    STAssertTrue(theAttributedString != nil, @"message should have an message id.");

    //NSString *thePlainString = [theAttributedString string];
    
    //NSLog(@"thePlainString = %@", thePlainString);
    [pool release];
}

@end
