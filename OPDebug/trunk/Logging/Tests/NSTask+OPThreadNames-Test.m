//
//  $Id:NSTask+OPThreadNames-Test.m$
//  OPDebug
//
//  Created by Jörg Westheide on 24.11.2005.
//  Copyright (c) 2005 Objectpark.org. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>

#import "NSThread+OPThreadNames.h"


@interface NSTask_OPThreadNames_Test : SenTestCase
@end

@implementation NSTask_OPThreadNames_Test

- (void) testMainThread
    {
    NSThread *mainThread = [NSThread currentThread];
    
    STAssertEqualObjects([mainThread name], @"MAIN",
                         @"Name of main thread is wrong");
    
    [mainThread setName:@"New Main Thread Name"];
    STAssertEqualObjects([mainThread name], @"New Main Thread Name",
                         @"New name of main thread is wrong");
    
    [mainThread setName:nil];
    STAssertEqualObjects([mainThread name], @"MAIN",
                         @"Restoring of thread name failed");
    }
    

- (void) test2ndThread
    {
    // improve by removing the hardcoded thread number (potential source of failure)
    NSThread *thread = [[[NSThread alloc] init] autorelease];
    
    STAssertEqualObjects([thread name], @"2",
                         @"Name of the 2nd thread is wrong");
    
    [thread setName:@"Thread #2"];
    STAssertEqualObjects([thread name], @"Thread #2",
                         @"New name of 2nd thread is wrong");
    
    [thread setName:nil];
    STAssertEqualObjects([thread name], @"2",
                         @"Restoring of the 2nd thread's name failed");
    }
    
@end
