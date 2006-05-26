//
//  TestOPJob.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 26.05.06.
//  Copyright (c) 2006 __MyCompanyName__. All rights reserved.
//

#import "TestOPJob.h"
#import "OPJob.h"
#include <unistd.h>

@implementation TestOPJob

- (void)setUp
{
    [OPJob setMaxThreads:2];
}

- (void)jobToTest:(NSMutableDictionary *)arguments
{
    //NSDictionary *args = [jobDescription objectForKey:OPJobArguments];
    //NSLog(@"Hello, I'm job with name: %@", [args objectForKey: @"name"]);
    
    STAssertTrue([OPJob job] != nil, @"not %@", [OPJob job]);
    
    [[OPJob job] setResult:@"TestResult"];
    
    sleep(2);
    
    if ([[OPJob job] shouldTerminate])
    {
        [[OPJob job] setResult:@"Terminated"];
        return;
    }
    
    sleep(3);
}

- (void) testBasics
{
    OPJob *job1 = [OPJob scheduleJobWithName:@"job1" target:self selector:@selector(jobToTest:) argument:[NSDictionary dictionaryWithObject:@"Basic Job 1" forKey:@"name"] synchronizedObject:nil];
    OPJob *job2 = [OPJob scheduleJobWithName:@"job2" target:self selector:@selector(jobToTest:) argument:[NSDictionary dictionaryWithObject:@"Basic Job 2" forKey:@"name"] synchronizedObject:nil];
    OPJob *job3 = [OPJob scheduleJobWithName:@"job3" target:self selector:@selector(jobToTest:) argument:[NSDictionary dictionaryWithObject:@"Basic Job 3" forKey:@"name"] synchronizedObject:nil];
    
	// sleep(1);
	
    STAssertTrue([OPJob maxThreads] == 2, @"Max 2 Threads allowed otherwise many tests will fail.");
	
    STAssertTrue([OPJob activeThreadCount] == 2, @"2 should be active");
	
    while ([job1 isRunning])
    {
        //NSLog(@"job1 still running...");
        sleep(1);
    }
    
    //NSLog(@"job1 completed");
	
    while ([job2 isRunning])
    {
        //NSLog(@"job2 still running...");
        sleep(1);
    }
    
    //NSLog(@"job2 completed");
	
    //sleep(1);
    
    STAssertTrue([OPJob activeThreadCount] == 1, @"1 should be active");
    STAssertTrue([OPJob idleThreadCount] == 1, @"1 should be idle");
	
    while ([job3 isRunning])
    {
        //NSLog(@"job3 still running...");
        sleep(1);
    }
    
    //NSLog(@"job3 completed");    
    
    STAssertTrue([OPJob idleThreadCount] == 2, @"all threads should be idle");
    STAssertTrue([OPJob activeThreadCount] == 0, @"no thread should be active");
}

- (void)testSynchronizing
{
    OPJob *jobKoeln1 = [OPJob scheduleJobWithName:@"koeln1" target:self selector:@selector(jobToTest:) argument:[NSDictionary dictionaryWithObject:@"Job Koeln1" forKey:@"name"] synchronizedObject:@"Koeln"];
    OPJob *jobKoeln2 = [OPJob scheduleJobWithName:@"koeln2" target:self selector:@selector(jobToTest:) argument:[NSDictionary dictionaryWithObject:@"Job Koeln2" forKey:@"name"] synchronizedObject:@"Koeln"];
    OPJob *jobDuisburg = [OPJob scheduleJobWithName:@"duisburg" target:self selector:@selector(jobToTest:) argument:[NSDictionary dictionaryWithObject:@"Job Duisburg" forKey:@"name"] synchronizedObject:@"Duisburg"];
    
    sleep(1);
    
    STAssertTrue([jobKoeln1 isRunning], @"Koeln1 soll laufen");
    STAssertFalse([jobKoeln2 isRunning], @"Koeln2 soll nicht laufen");
    STAssertTrue([jobDuisburg isRunning], @"jobDuisburg soll laufen");
    STAssertTrue([OPJob activeThreadCount] == 2, @"2 should be active but only %d are.", [OPJob activeThreadCount]);
    
    while ([jobKoeln1 isRunning])
    {
        //NSLog(@"jobKoeln1 still running...");
        sleep(1);
    }
    
    //NSLog(@"jobKoeln1 completed");
    
    while ([jobDuisburg isRunning])
    {
        //NSLog(@"jobDuisburg still running...");
        sleep(1);
    }
    
    //NSLog(@"jobDuisburg completed");
    
    sleep(1);
    
    STAssertTrue([OPJob activeThreadCount] == 1, @"1 should be active");
    STAssertTrue([OPJob idleThreadCount] == 1, @"1 should be idle");
    
    while ([jobKoeln2 isRunning])
    {
        //NSLog(@"jobKoeln2 still running...");
        sleep(1);
    }
    
    //NSLog(@"jobKoeln2 completed");    
    
    STAssertTrue([OPJob idleThreadCount] == 2, @"all threads should be idle");
    STAssertTrue([OPJob activeThreadCount] == 0, @"no thread should be active");
}

- (void)testResult
{
    [OPJob removeAllFinishedJobs];
    STAssertTrue([[OPJob finishedJobs] count] == 0, @"at least one finished job in place");
    
    OPJob *jobKoeln1 = [OPJob scheduleJobWithName:@"koeln1" target:self selector:@selector(jobToTest:) argument:[NSDictionary dictionaryWithObject:@"Job Koeln1" forKey:@"name"] synchronizedObject:@"Koeln"];
    
    sleep(1);
    
    STAssertTrue([jobKoeln1 isRunning], @"Koeln1 soll laufen");
    STAssertTrue([OPJob activeThreadCount] == 1, @"1 should be active but only %d are.", [OPJob activeThreadCount]);
    
    while ([jobKoeln1 isRunning])
    {
        //NSLog(@"jobKoeln1 still running...");
        sleep(1);
    }
    
    //NSLog(@"jobKoeln1 completed");
    STAssertTrue([jobKoeln1 isFinished], @"should be finished");
    STAssertTrue([[jobKoeln1 result] isEqual:@"TestResult"], @"wrong result %@ = TestResult", [jobKoeln1 result]);
    STAssertTrue([OPJob activeThreadCount] == 0, @"no thread should be active");
    
    STAssertTrue([[OPJob finishedJobs] count] == 1, @"not one finished job in place");
    [OPJob removeFinishedJob:jobKoeln1];
    STAssertTrue([[OPJob finishedJobs] count] == 0, @"at least one finished job in place");
}

- (void)testTermination
{
    OPJob *job1 = [OPJob scheduleJobWithName:@"job1" target:self selector:@selector(jobToTest:) argument:[NSDictionary dictionaryWithObject:@"testTermination" forKey:@"name"] synchronizedObject:nil];
    
    sleep(1);
    
    [job1 suggestTerminating];
    
    while ([job1 isRunning])
    {
        //NSLog(@"job1 still running...");
        sleep(1);
    }
    
    STAssertTrue([[job1 result] isEqual:@"Terminated"], @"wrong result %@ = Terminated", [job1 result]);
}

@end
