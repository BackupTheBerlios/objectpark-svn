//
//  OPDebug-Tests.m
//  OPDebug
//
//  Created by Jörg Westheide on 29.09.2005.
//  Copyright 2005 Objectpark.org. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
@interface OPDebugLog_Tests : SenTestCase
@end


#import "OPDebugLog.h"
#import "OPLogMock.h"


#define OPTestDebug  @"OPTestDebug"

@implementation OPDebugLog_Tests

- (void) setUp
    {
    NSDebugEnabled = 1;
    // using OPLogMock here ensures the shared instance to be a required mock object
    [[OPLogMock sharedInstance] log:nil];
    STAssertTrue([[OPLogMock sharedInstance] loggedMessage] == nil, @"Could not reset the logged Message to nil");
    
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
    STAssertTrue([[[OPLogMock sharedInstance] loggedMessage] hasPrefix:@"["],
                 @"logged message should start with '[' but is %@", [[OPLogMock sharedInstance] loggedMessage]);
    STAssertTrue([[[OPLogMock sharedInstance] loggedMessage] hasSuffix:@"] Some Domain (OPINFO): "],
                 @"logged message should end with '] Some Domain (OPINFO): ' but is %@", [[OPLogMock sharedInstance] loggedMessage]);
    }
    
    
- (void) testOPDebugLog
    {
    [[OPDebugLog sharedInstance] setAspects:OPINFO forDomain:@"Some Domain"];
    
    NSString *message = @"Yes, this should be printed!";
    
    OPDebugLog(@"Some Domain", OPINFO, message);
    
    [[OPDebugLog sharedInstance] removeAspects:OPINFO forDomain:@"Some Domain"];    
    
    STAssertNotNil([[OPLogMock sharedInstance] loggedMessage],
                   @"A message should have been logged but wasn't.");
    STAssertEqualObjects([[OPLogMock sharedInstance] loggedMessage], [@"[1] Some Domain (OPINFO): " stringByAppendingString:message],
                         @"A wrong message has been logged");
    }
    
    
- (void) testOPDebugLogWithAdditionalArg
    {
    [[OPDebugLog sharedInstance] setAspects:OPINFO forDomain:@"Some Domain"];
    
    OPDebugLog(@"Some Domain", OPINFO, @"Here we have an %@", @"argument");
    
    [[OPDebugLog sharedInstance] removeAspects:OPINFO forDomain:@"Some Domain"];    
    
    STAssertNotNil([[OPLogMock sharedInstance] loggedMessage],
                   @"A message should have been logged but wasn't.");
    STAssertEqualObjects([[OPLogMock sharedInstance] loggedMessage], @"[1] Some Domain (OPINFO): Here we have an argument",
                         @"A wrong message has been logged");
    }
    
    
@end
