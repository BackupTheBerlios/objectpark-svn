//
//  $Id:OPDebug-Tests.m$
//  OPDebug
//
//  Created by Jörg Westheide on 29.09.2005.
//  Copyright 2005 Objectpark.org. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
@interface OPLog_Tests : SenTestCase
@end


#import "OPLog.h"
#import "OPLogMock.h"


#define OPTestDebug  OPL_DOMAIN  @"OPTestDebug"

@implementation OPLog_Tests

- (void) setUp
    {
    NSDebugEnabled = 1;
    // using OPLogMock here ensures the shared instance to be a required mock object
    [[OPLogMock sharedInstance] log:nil];
    STAssertTrue([[OPLogMock sharedInstance] loggedMessage] == nil,
                 @"Could not reset the logged Message to nil");
    
    [[OPLogMock sharedInstance] setAspects:OPALL forDomain:OPTestDebug];
    }
    
    
- (void) tearDown
    {
    NSDebugEnabled = 0;
    [[OPLogMock sharedInstance] removeAspectsForDomain:OPTestDebug];
    }
    
    


- (void) testOPDebugLogWithNonExistentDomain
    {
    OPDebugLog(@"Non Existent Domain", OPERROR, @"OOPS! This should not have been printed!");
    NSString *message = [[OPLogMock sharedInstance] loggedMessage];
    STAssertTrue(message == nil, @"A message has been logged erroneously. The message is %@", message);
    }
    
    
- (void) testOPDebugLogPrefix
    {
    OPDebugLog(@"Some Domain", OPINFO, @"");
    STAssertEqualObjects([[OPLogMock sharedInstance] loggedMessage],
                         @"Some Domain (OPINFO): ",
                         @"log prefix doesn't match");
    }
    
    
- (void) testOPDebugLog
    {
    [[OPLog sharedInstance] setAspects:OPINFO forDomain:@"Some Domain"];
    
    NSString *message = @"Yes, this should be printed!";
    
    OPDebugLog(@"Some Domain", OPINFO, message);
    
    [[OPLog sharedInstance] removeAspects:OPINFO forDomain:@"Some Domain"];    
    
    STAssertNotNil([[OPLogMock sharedInstance] loggedMessage],
                   @"A message should have been logged but wasn't.");
    STAssertEqualObjects([[OPLogMock sharedInstance] loggedMessage],
                         [@"Some Domain (OPINFO): " stringByAppendingString:message],
                         @"A wrong message has been logged");
    }
    
    
- (void) testOPDebugLogWithAdditionalArg
    {
    [[OPLog sharedInstance] setAspects:OPINFO forDomain:@"Some Domain"];
    
    OPDebugLog(@"Some Domain", OPINFO, @"Here we have an %@", @"argument");
    
    [[OPLog sharedInstance] removeAspects:OPINFO forDomain:@"Some Domain"];    
    
    STAssertNotNil([[OPLogMock sharedInstance] loggedMessage],
                   @"A message should have been logged but wasn't.");
    STAssertEqualObjects([[OPLogMock sharedInstance] loggedMessage],
                         @"Some Domain (OPINFO): Here we have an argument",
                         @"A wrong message has been logged");
    }
    
    
- (void) testOPLog
    {
    NSDebugEnabled = 0;
        
    NSString *message = @"Yes, this should be printed!";
    
    OPLog(message);
    
    STAssertNotNil([[OPLogMock sharedInstance] loggedMessage],
                   @"A message should have been logged but wasn't.");
    STAssertEqualObjects([[OPLogMock sharedInstance] loggedMessage],
                         message,
                         @"A wrong message has been logged");
    }
    
    
- (void) testOPLogWithAdditionalArg
    {
    NSDebugEnabled = 0;
        
    OPLog(@"Here we have an %@", @"argument");
    
    STAssertNotNil([[OPLogMock sharedInstance] loggedMessage],
                   @"A message should have been logged but wasn't.");
    STAssertEqualObjects([[OPLogMock sharedInstance] loggedMessage],
                         @"Here we have an argument",
                         @"A wrong message has been logged");
    }
    
    
@end
