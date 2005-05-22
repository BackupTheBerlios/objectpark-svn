//
//  TestOPJobs.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 22.05.05.
//  Copyright (c) 2005 __MyCompanyName__. All rights reserved.
//

#import "TestOPJobs.h"
#import "OPJobs.h"
#include <unistd.h>

@implementation TestOPJobs

- (void)jobToTest:(NSMutableDictionary *)jobDescription
{
    //NSDictionary *args = [jobDescription objectForKey:OPJobArguments];
    //NSLog(@"Hello, I'm job with name: %@", [args objectForKey:@"name"]);
    
    sleep(5);
}

- (void)testBasics
{
    unsigned jobId1 = [OPJobs scheduleJobWithTarget:self selector:@selector(jobToTest:) arguments:[NSDictionary dictionaryWithObject:@"Basic Job 1" forKey:@"name"] synchronizedObject:nil];
    unsigned jobId2 = [OPJobs scheduleJobWithTarget:self selector:@selector(jobToTest:) arguments:[NSDictionary dictionaryWithObject:@"Basic Job 2" forKey:@"name"] synchronizedObject:nil];
    unsigned jobId3 = [OPJobs scheduleJobWithTarget:self selector:@selector(jobToTest:) arguments:[NSDictionary dictionaryWithObject:@"Basic Job 3" forKey:@"name"] synchronizedObject:nil];
    
    sleep(1);
    
    STAssertTrue([OPJobs activeThreadCount] == 2, @"2 should be active");

    while ([OPJobs jobIsRunning:jobId1])
    {
        //NSLog(@"job1 still running...");
        sleep(1);
    }
    
    //NSLog(@"job1 completed");

    while ([OPJobs jobIsRunning:jobId2])
    {
        //NSLog(@"job2 still running...");
        sleep(1);
    }
    
    //NSLog(@"job2 completed");

    sleep(1);
    
    STAssertTrue([OPJobs activeThreadCount] == 1, @"1 should be active");
    STAssertTrue([OPJobs idleThreadCount] == 1, @"1 should be idle");

    while ([OPJobs jobIsRunning:jobId3])
    {
        //NSLog(@"job3 still running...");
        sleep(1);
    }
    
    //NSLog(@"job3 completed");    
    
    STAssertTrue([OPJobs idleThreadCount] == 2, @"all threads should be idle");
    STAssertTrue([OPJobs activeThreadCount] == 0, @"no thread should be active");
}

- (void)testSynchronizing
{
    unsigned jobKoeln1 = [OPJobs scheduleJobWithTarget:self selector:@selector(jobToTest:) arguments:[NSDictionary dictionaryWithObject:@"Job Koeln1" forKey:@"name"] synchronizedObject:@"Koeln"];
    unsigned jobKoeln2 = [OPJobs scheduleJobWithTarget:self selector:@selector(jobToTest:) arguments:[NSDictionary dictionaryWithObject:@"Job Koeln2" forKey:@"name"] synchronizedObject:@"Koeln"];
    unsigned jobDuisburg = [OPJobs scheduleJobWithTarget:self selector:@selector(jobToTest:) arguments:[NSDictionary dictionaryWithObject:@"Job Duisburg" forKey:@"name"] synchronizedObject:@"Duisburg"];
    
    sleep(1);
    
    STAssertTrue([OPJobs jobIsRunning:jobKoeln1], @"Koeln1 soll laufen");
    STAssertFalse([OPJobs jobIsRunning:jobKoeln2], @"Koeln2 soll nicht laufen");
    STAssertTrue([OPJobs jobIsRunning:jobDuisburg], @"jobDuisburg soll laufen");
    STAssertTrue([OPJobs activeThreadCount] == 2, @"2 should be active but only %d are.", [OPJobs activeThreadCount]);
    
    while ([OPJobs jobIsRunning:jobKoeln1])
    {
        //NSLog(@"jobKoeln1 still running...");
        sleep(1);
    }
    
    //NSLog(@"jobKoeln1 completed");
    
    while ([OPJobs jobIsRunning:jobDuisburg])
    {
        //NSLog(@"jobDuisburg still running...");
        sleep(1);
    }
    
    //NSLog(@"jobDuisburg completed");
    
    sleep(1);
    
    STAssertTrue([OPJobs activeThreadCount] == 1, @"1 should be active");
    STAssertTrue([OPJobs idleThreadCount] == 1, @"1 should be idle");
    
    while ([OPJobs jobIsRunning:jobKoeln2])
    {
        //NSLog(@"jobKoeln2 still running...");
        sleep(1);
    }
    
    //NSLog(@"jobKoeln2 completed");    
    
    STAssertTrue([OPJobs idleThreadCount] == 2, @"all threads should be idle");
    STAssertTrue([OPJobs activeThreadCount] == 0, @"no thread should be active");
}

@end
