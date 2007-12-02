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
#import "OPInternetMessage.h"
#import "EDMessagePart+OPExtensions.h"

@implementation TestOPMultipartContentCoder

- (void) tearDown
{
}

- (void)testAttributedString
{
    // read message from resources:
    OPMBoxFile *mboxFile;
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    mboxFile = [OPMBoxFile mboxWithPath:[[NSBundle bundleWithIdentifier:@"org.objectpark.InternetMessageTest"] pathForResource: @"multipartAlternativeTest-mbox" ofType:@"txt"]];
    STAssertTrue(mboxFile != nil, @"mbox could not be read from resources.");
    NSEnumerator *enumerator = [mboxFile messageDataEnumerator];
    NSData *transferData = [[enumerator nextObject] transferDataFromMboxData];
    STAssertTrue(transferData != nil, @"transferData could not be enumerated.");
	
	OPInternetMessage *internetMessage = [[[OPInternetMessage alloc] initWithTransferData:transferData] autorelease];
	    
    STAssertTrue([internetMessage messageId] != nil, @"message should have an message id.");

    NSAttributedString *theAttributedString = [[NSMutableAttributedString alloc] initWithAttributedString:[internetMessage contentWithPreferredContentTypes:[EDMessagePart preferredContentTypes] attributed:YES]];
    STAssertTrue(theAttributedString != nil, @"message should have an message id.");

    //NSString *thePlainString = [theAttributedString string];
    
    //NSLog(@"thePlainString = %@", thePlainString);
    [pool release];
}

@end
