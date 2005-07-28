//
//  TestOPJobs.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 22.05.05.
//  Copyright (c) 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "TestOPJobs.h"
#import "OPJobs.h"
#include <unistd.h>

@implementation TestOPJobs

- (void)setUp
{
    [OPJobs setMaxThreads:2];
}

- (void)jobToTest:(NSMutableDictionary *)arguments
{
    //NSDictionary *args = [jobDescription objectForKey:OPJobArguments];
    //NSLog(@"Hello, I'm job with name: %@", [args objectForKey:@"name"]);
    
    STAssertTrue([OPJobs jobId] != 0, @"not %u", [OPJobs jobId]);
    
    [OPJobs setResult:@"TestResult"];
    
    sleep(2);
    
    if ([OPJobs shouldTerminate])
    {
        [OPJobs setResult:@"Terminated"];
        return;
    }
    
    sleep(3);
}

- (void)testBasics
{
    NSNumber *jobId1 = [OPJobs scheduleJobWithName:@"job1" target:self selector:@selector(jobToTest:) arguments:[NSDictionary dictionaryWithObject:@"Basic Job 1" forKey:@"name"] synchronizedObject:nil];
    NSNumber *jobId2 = [OPJobs scheduleJobWithName:@"job2" target:self selector:@selector(jobToTest:) arguments:[NSDictionary dictionaryWithObject:@"Basic Job 2" forKey:@"name"] synchronizedObject:nil];
    NSNumber *jobId3 = [OPJobs scheduleJobWithName:@"job3" target:self selector:@selector(jobToTest:) arguments:[NSDictionary dictionaryWithObject:@"Basic Job 3" forKey:@"name"] synchronizedObject:nil];
    
   // sleep(1);
        
    STAssertTrue([OPJobs maxThreads] == 2, @"Max 2 Threads allowed otherwise many tests will fail.");

    STAssertTrue([OPJobs activeThreadCount] == 2, @"2 should be active");

    while ([OPJobs isJobRunning:jobId1])
    {
        //NSLog(@"job1 still running...");
        sleep(1);
    }
    
    //NSLog(@"job1 completed");

    while ([OPJobs isJobRunning:jobId2])
    {
        //NSLog(@"job2 still running...");
        sleep(1);
    }
    
    //NSLog(@"job2 completed");

    //sleep(1);
    
    STAssertTrue([OPJobs activeThreadCount] == 1, @"1 should be active");
    STAssertTrue([OPJobs idleThreadCount] == 1, @"1 should be idle");

    while ([OPJobs isJobRunning:jobId3])
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
    NSNumber *jobKoeln1 = [OPJobs scheduleJobWithName:@"koeln1" target:self selector:@selector(jobToTest:) arguments:[NSDictionary dictionaryWithObject:@"Job Koeln1" forKey:@"name"] synchronizedObject:@"Koeln"];
    NSNumber *jobKoeln2 = [OPJobs scheduleJobWithName:@"koeln2" target:self selector:@selector(jobToTest:) arguments:[NSDictionary dictionaryWithObject:@"Job Koeln2" forKey:@"name"] synchronizedObject:@"Koeln"];
    NSNumber *jobDuisburg = [OPJobs scheduleJobWithName:@"duisburg" target:self selector:@selector(jobToTest:) arguments:[NSDictionary dictionaryWithObject:@"Job Duisburg" forKey:@"name"] synchronizedObject:@"Duisburg"];
    
    sleep(1);
    
    STAssertTrue([OPJobs isJobRunning:jobKoeln1], @"Koeln1 soll laufen");
    STAssertFalse([OPJobs isJobRunning:jobKoeln2], @"Koeln2 soll nicht laufen");
    STAssertTrue([OPJobs isJobRunning:jobDuisburg], @"jobDuisburg soll laufen");
    STAssertTrue([OPJobs activeThreadCount] == 2, @"2 should be active but only %d are.", [OPJobs activeThreadCount]);
    
    while ([OPJobs isJobRunning:jobKoeln1])
    {
        //NSLog(@"jobKoeln1 still running...");
        sleep(1);
    }
    
    //NSLog(@"jobKoeln1 completed");
    
    while ([OPJobs isJobRunning:jobDuisburg])
    {
        //NSLog(@"jobDuisburg still running...");
        sleep(1);
    }
    
    //NSLog(@"jobDuisburg completed");
    
    sleep(1);
    
    STAssertTrue([OPJobs activeThreadCount] == 1, @"1 should be active");
    STAssertTrue([OPJobs idleThreadCount] == 1, @"1 should be idle");
    
    while ([OPJobs isJobRunning:jobKoeln2])
    {
        //NSLog(@"jobKoeln2 still running...");
        sleep(1);
    }
    
    //NSLog(@"jobKoeln2 completed");    
    
    STAssertTrue([OPJobs idleThreadCount] == 2, @"all threads should be idle");
    STAssertTrue([OPJobs activeThreadCount] == 0, @"no thread should be active");
}

- (void)testResult
{
    [OPJobs removeAllFinishedJobs];
    STAssertTrue([[OPJobs finishedJobs] count] == 0, @"at least one finished job in place");
    
    NSNumber *jobKoeln1 = [OPJobs scheduleJobWithName:@"koeln1" target:self selector:@selector(jobToTest:) arguments:[NSDictionary dictionaryWithObject:@"Job Koeln1" forKey:@"name"] synchronizedObject:@"Koeln"];
    
    sleep(1);
    
    STAssertTrue([OPJobs isJobRunning:jobKoeln1], @"Koeln1 soll laufen");
    STAssertTrue([OPJobs activeThreadCount] == 1, @"1 should be active but only %d are.", [OPJobs activeThreadCount]);
    
    while ([OPJobs isJobRunning:jobKoeln1])
    {
        //NSLog(@"jobKoeln1 still running...");
        sleep(1);
    }
    
    //NSLog(@"jobKoeln1 completed");
    STAssertTrue([OPJobs isJobFinished:jobKoeln1], @"should be finished");
    STAssertTrue([[OPJobs resultForJob:jobKoeln1] isEqual:@"TestResult"], @"wrong result %@ = TestResult", [OPJobs resultForJob:jobKoeln1]);
    STAssertTrue([OPJobs activeThreadCount] == 0, @"no thread should be active");
    
    STAssertTrue([[OPJobs finishedJobs] count] == 1, @"not one finished job in place");
    [OPJobs removeFinishedJob:jobKoeln1];
    STAssertTrue([[OPJobs finishedJobs] count] == 0, @"at least one finished job in place");
}

- (void)testTermination
{
    NSNumber *job1 = [OPJobs scheduleJobWithName:@"job1" target:self selector:@selector(jobToTest:) arguments:[NSDictionary dictionaryWithObject:@"testTermination" forKey:@"name"] synchronizedObject:nil];
    
    sleep(1);
    
    [OPJobs suggestTerminatingJob:job1];
    
    while ([OPJobs isJobRunning:job1])
    {
        //NSLog(@"job1 still running...");
        sleep(1);
    }
    
    STAssertTrue([[OPJobs resultForJob:job1] isEqual:@"Terminated"], @"wrong result %@ = Terminated", [OPJobs resultForJob:job1]);
}

@end
