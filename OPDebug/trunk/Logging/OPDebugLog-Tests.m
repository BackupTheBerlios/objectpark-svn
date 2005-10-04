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


@implementation OPDebugLog_Tests

- (void) testOPDebugLogWithNonExistentDomain
    {
    NSDebugEnabled = 1;
    
    OPDebugLog(@"Non Existent Domain", OPERROR, "OOPS! This should not be printed!");
    
    // add test here
    
    NSDebugEnabled = 0;
    }
    
    
- (void) testOPDebugLog
    {
    NSDebugEnabled = 1;
    
    [[OPDebugLog sharedInstance] setAspects:OPINFO forDomain:@"Some Domain"];
    
    OPDebugLog(@"Some Domain", OPINFO, "Yes, this should be printed!");
    
    [[OPDebugLog sharedInstance] removeAspects:OPINFO forDomain:@"Some Domain"];    
    
    // add test here
    
    NSDebugEnabled = 0;
    }
    
    
- (void) testOPDebugLogWithAdditionalArg
    {
    NSDebugEnabled = 1;
    
    [[OPDebugLog sharedInstance] setAspects:OPINFO forDomain:@"Some Domain"];
    
    OPDebugLog(@"Some Domain", OPINFO, "Here we have an %@", @"argument");
    
    [[OPDebugLog sharedInstance] removeAspects:OPINFO forDomain:@"Some Domain"];    
    
    // add test here
    
    NSDebugEnabled = 0;
    }
    
    
@end
