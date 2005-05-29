//
//  TestNSData+MessageUtils.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 28.05.05.
//  Copyright (c) 2005 __MyCompanyName__. All rights reserved.
//

#import "TestNSData+MessageUtils.h"
#import "NSData+MessageUtils.h"
#import <Foundation/Foundation.h>

@implementation TestNSData_MessageUtils

- (void)testMboxData
{
    NSData *transferData = [@"From: mailer@daemon.org\r\n\r\nTest\r\n" dataUsingEncoding:NSASCIIStringEncoding];
    NSString *expectedString = @"From: mailer@daemon.org\n\nTest\n\n";
    NSData *mboxData = [transferData mboxDataFromTransferDataWithEnvSender:nil];
    NSString *mboxString = [[[NSString alloc] initWithData:mboxData encoding:NSASCIIStringEncoding] autorelease];
    
    STAssertTrue([mboxString hasPrefix:@"From MAILER-DAEMON"], @"nee");

    NSRange range = [mboxString rangeOfString:@"\n"];
     
    STAssertEqualObjects(expectedString, [mboxString substringFromIndex:range.location + range.length], @"nee");
    NSData *transferDataConvertedBack = [mboxData transferDataFromMboxData];
    
    STAssertEqualObjects(transferDataConvertedBack, transferData, @"nee");
}

@end
