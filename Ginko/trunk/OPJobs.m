//
//  OPJobs.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 22.05.05.
//  Copyright 2005 Objectpark Group. All rights reserved.
//

#import "OPJobs.h"

@implementation OPJobs
/*" Engine for using worker threads. Spawns worker threads as needed (limited by a maximum) for executing jobs. Jobs can mutual exclude other jobs from running at the same time by using synchronized objects (see below). Jobs are put into a list of pending jobs and the worker threads are executing them as they are eligible and a worker thread would be idle. "*/

NSString *OPJobWillStartNotification = @"OPJobWillStartNotification";
NSString *OPJobDidFinishNotification = @"OPJobDidFinishNotification";

enum {OPNoPendingJobs, OPPendingJobs};

NSString *OPJobId = @"OPJobId";
NSString *OPJobTarget = @"OPJobTarget";
NSString *OPJobSelector = @"OPJobSelector";
NSString *OPJobArguments = @"OPJobArguments";
NSString *OPJobResult = @"OPJobResult";
NSString *OPJobUnhandledException = @"OPJobUnhandledException";
NSString *OPJobSynchronizedObject = @"OPJobSynchronizedObject";
NSString *OPJobWorkerThread = @"OPJobWorkerThread";

static NSConditionLock *jobsLock = nil;

static NSMutableArray *pendingJobs = nil;
static NSMutableArray *runningJobs = nil;
static NSMutableArray *finishedJobs = nil;

static NSMutableSet *synchronizedObjects = nil;

static NSMutableArray *idleThreads = nil;
static NSMutableArray *activeThreads = nil;

static unsigned maxThreads = 2;
static unsigned threadCount = 0;
static unsigned nextJobId = 0;

+ (void)initialize
{
    jobsLock = [[NSConditionLock alloc] initWithCondition:OPNoPendingJobs];

    pendingJobs = [[NSMutableArray alloc] init];
    runningJobs = [[NSMutableArray alloc] init];
    finishedJobs = [[NSMutableArray alloc] init];
        
    idleThreads = [[NSMutableArray alloc] init];
    activeThreads = [[NSMutableArray alloc] init];
    
    synchronizedObjects = [[NSMutableSet alloc] init];
}

+ (NSMutableDictionary *)nextEligibleJob
/*" Returns the next job that is allowed to run. Caution: Run locked only! "*/
{
    NSMutableDictionary *result = nil;
    
    int count = [pendingJobs count];
    if (count)
    {
        int i; 
        for (i = 0; i < count; i++)
        {
            NSMutableDictionary *jobDescription = [pendingJobs objectAtIndex:i];
            id synchronizedObject = [jobDescription objectForKey:OPJobSynchronizedObject];
            
            if (synchronizedObject)
            {
                if(![synchronizedObjects containsObject:synchronizedObject])
                {
                    result = jobDescription;
                    break;
                }
            }
            else
            {
                result = jobDescription;
                break;
            }
        }
    }
    
    //NSLog(@"nextEligibleJob = %@", result);
    return result;
}

+ (unsigned)scheduleJobWithTarget:(NSObject *)aTarget selector:(SEL)aSelector arguments:(NSDictionary *)someArguments synchronizedObject:(id <NSCopying>)aSynchronizedObject
/*" Schedules a job for being executed by a worker thread as soon as a unemployed worker thread is present and the execution of this job isn't mutual excluded by a currently running job. 

    aTarget is the object on which aSelector will be executed with someArguments as the only argument. 

    aSynchronizedObject may be nil but can be used for excluding other jobs with equal synchronized objects for running at the same time. aSelector must denote a method that takes exactly one parameter of the type #{NSMutableDictionary}. The dictionary holds someArguments (see the source code of the corresponding unit tests for an example). 

    An optional result should be set by invoking #{-setResult:} from within the job. 

    Returns the job's unique id which has to be used for inquiries lateron. "*/
{
    [jobsLock lock];

    NSMutableDictionary *jobDescription = [NSMutableDictionary dictionary];
    unsigned jobId = nextJobId++;
    
    [jobDescription setObject:[NSNumber numberWithUnsignedInt:jobId] forKey:OPJobId];
    [jobDescription setObject:aTarget forKey:OPJobTarget];
    [jobDescription setObject:NSStringFromSelector(aSelector) forKey:OPJobSelector];
    [jobDescription setObject:[[someArguments copy] autorelease] forKey:OPJobArguments];
    
    if (aSynchronizedObject)
    {
        [jobDescription setObject:aSynchronizedObject forKey:OPJobSynchronizedObject];
    }
    
    [pendingJobs addObject:jobDescription];
    
    // start new worker thread if no threads are idle and 
    // the maximum number of worker thread is not reached:
    if (([idleThreads count] == 0) && (threadCount < maxThreads))
    {
        [NSThread detachNewThreadSelector:@selector(workerThread:) toTarget:self withObject:nil];
        threadCount++;
    }
    
    [jobsLock unlockWithCondition:[self nextEligibleJob] ? OPPendingJobs : OPNoPendingJobs];
    
    return jobId;
}

+ (NSMutableDictionary *)nextPendingJobUnlockingSynchronizedObject:(id)anSynchronizedObject
/*" Returns the next eligile job description. Removes synchronization of anSynchroniziedObject (may be nil). Sets the job in running state. Caution: Run locked only! "*/
{
    NSMutableDictionary *result = nil;
    
    if (anSynchronizedObject)
    {
        [synchronizedObjects removeObject:anSynchronizedObject];
    }
    
    result = [self nextEligibleJob];
    
    if (result)
    {
        id synchronizedObject = [result objectForKey:OPJobSynchronizedObject];
        
        if (synchronizedObject)
        {
            [synchronizedObjects addObject:synchronizedObject];
        }
        
        [runningJobs addObject:result];
        [pendingJobs removeObject:result];
    }
    
    return result;
}

+ (void)noteJobWillStart:(NSNumber *)anJobId
/*" Performed on main thread to notify of the upcoming start of a job. "*/
{
    [[NSNotificationCenter defaultCenter] postNotificationName:OPJobWillStartNotification object:anJobId];
}

+ (void)noteJobDidFinish:(NSNumber *)anJobId
/*" Performed on main thread to notifiy of the finishing of a job. "*/
{
    [[NSNotificationCenter defaultCenter] postNotificationName:OPJobDidFinishNotification object:anJobId];
}

+ (void)workerThread:(id)args
/*" The worker threads' detached method. "*/
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    [jobsLock lock];
    
    [idleThreads addObject:[NSThread currentThread]];
    //NSLog(@"Thread %@ started:", [NSThread currentThread]);
    
    [jobsLock unlockWithCondition:[self nextEligibleJob] ? OPPendingJobs : OPNoPendingJobs];
    
    for(;;)
    {
        [pool drain];

        [jobsLock lockWhenCondition:OPPendingJobs];

        NSMutableDictionary *jobDescription = [self nextPendingJobUnlockingSynchronizedObject:nil];
                        
        // this thread is no longer idle but working:
        [idleThreads removeObject:[NSThread currentThread]];
        [activeThreads addObject:[NSThread currentThread]];
        
        [jobsLock unlockWithCondition:[self nextEligibleJob] ? OPPendingJobs : OPNoPendingJobs];

        while (jobDescription)
        {
            //NSLog(@"Working on job with description: %@", jobDescription);
            
            @try {
                // do job here:
                NSObject *jobTarget = [jobDescription objectForKey:OPJobTarget];
                SEL jobSelector = NSSelectorFromString([jobDescription objectForKey:OPJobSelector]);
                
                [jobDescription setObject:[NSThread currentThread] forKey:OPJobWorkerThread];
                                
                [self performSelectorOnMainThread:@selector(noteJobWillStart:) withObject:[jobDescription objectForKey:OPJobId] waitUntilDone:NO];
                
                [jobTarget performSelector:jobSelector withObject:[jobDescription objectForKey:OPJobArguments]];
            }
            @catch (NSException *exception) {
                NSLog(@"Job (%@) caused Exception: %@", jobDescription, exception);
                [jobDescription setObject:exception forKey:OPJobUnhandledException];
            }
            @finally {
                [jobsLock lock];
                
                [jobDescription removeObjectForKey:OPJobWorkerThread];
                
                [finishedJobs addObject:jobDescription];
                [runningJobs removeObject:jobDescription];

                [self performSelectorOnMainThread:@selector(noteJobDidFinish:) withObject:[jobDescription objectForKey:OPJobId] waitUntilDone:NO];
                
                // try to get next job:
                jobDescription = [self nextPendingJobUnlockingSynchronizedObject:[jobDescription objectForKey:OPJobSynchronizedObject]];
                
                if (!jobDescription)
                {
                    [activeThreads removeObject:[NSThread currentThread]];
                    [idleThreads addObject:[NSThread currentThread]];
                }
                
                [jobsLock unlockWithCondition:[self nextEligibleJob] ? OPPendingJobs : OPNoPendingJobs];
            }
            
            [pool drain];
        }
    }
}

+ (BOOL)jobIsRunning:(unsigned)anJobId
/*" Returns YES if the job denoted by anJobId is currently running. NO otherwise. "*/
{
    BOOL result = NO;
    int i, count;
    
    [jobsLock lock];
    
    count = [runningJobs count];
    for (i = 0; i < count; i++)
    {
        if ([[[runningJobs objectAtIndex:i] objectForKey:OPJobId] unsignedIntValue] == anJobId)
        {
            result = YES;
            break;
        }
    }
    
    [jobsLock unlockWithCondition:[jobsLock condition]];
    
    return result;
}

+ (BOOL)jobIsFinished:(unsigned)anJobId
/*" Returns YES if the job denoted by anJobId is in the list of finished jobs. NO otherwise. "*/
{
    BOOL result = NO;
    int i, count;
    
    [jobsLock lock];
    
    count = [finishedJobs count];
    for (i = 0; i < count; i++)
    {
        if ([[[finishedJobs objectAtIndex:i] objectForKey:OPJobId] unsignedIntValue] == anJobId)
        {
            result = YES;
            break;
        }
    }
    
    [jobsLock unlockWithCondition:[jobsLock condition]];
    
    return result;
}

+ (id)resultForJob:(unsigned)anJobId
/*" Returns the result object for the job denoted by anJobId. nil, if no result was set. "*/
{
    id result = nil;
    int i, count;
    
    [jobsLock lock];
    
    count = [finishedJobs count];
    for (i = count - 1; i >= 0; i--)
    {
        if ([[[finishedJobs objectAtIndex:i] objectForKey:OPJobId] unsignedIntValue] == anJobId)
        {
            result = [[finishedJobs objectAtIndex:i] objectForKey:OPJobResult];
            break;
        }
    }
    
    [jobsLock unlockWithCondition:[jobsLock condition]];
    
    return result;
}

+ (void)setResult:(id)aResult
/*" Sets the result for the calling job. "*/
{
    int i, count;
    NSThread *jobThread = [NSThread currentThread];
    
    [jobsLock lock];
    
    count = [runningJobs count];
    for (i = count - 1; i >= 0; i--)
    {
        if ([[runningJobs objectAtIndex:i] objectForKey:OPJobWorkerThread] == jobThread)
        {
            [[runningJobs objectAtIndex:i] setObject:aResult forKey:OPJobResult];
            break;
        }
    }
    
    [jobsLock unlockWithCondition:[jobsLock condition]];
}

+ (int)idleThreadCount
/*" Returns the number of threads in idle state. "*/
{
    int result;
    
    [jobsLock lock];
    result = [idleThreads count];    
    [jobsLock unlockWithCondition:[jobsLock condition]];
    
    return result;
}

+ (int)activeThreadCount
/*" Returns the number of threads in active/running state. "*/
{
    int result;
    
    [jobsLock lock];
    result = [activeThreads count];    
    [jobsLock unlockWithCondition:[jobsLock condition]];
    
    return result;
}

+ (NSArray *)finishedJobs
/*" Returns the job ids of all finished jobs. "*/
{
    NSMutableArray *result = [NSMutableArray array];

    [jobsLock lock];
    NSEnumerator *enumerator = [finishedJobs objectEnumerator];
    NSDictionary *jobDescription;
    
    while (jobDescription = [enumerator nextObject])
    {
        [result addObject:[jobDescription objectForKey:OPJobId]];
    }
    
    [jobsLock unlockWithCondition:[jobsLock condition]];

    return result;
}

+ (BOOL)removeFinishedJob:(unsigned)anJobId
/*" Removes the job denoted by anJobId including all job information (e.g. the job's result) from the list of finished jobs. "*/
{
    BOOL result = NO;
    
    [jobsLock lock];
    NSEnumerator *enumerator = [finishedJobs objectEnumerator];
    NSDictionary *jobDescription;
    
    while (jobDescription = [enumerator nextObject])
    {
        if ([[jobDescription objectForKey:OPJobId] unsignedIntValue] == anJobId)
        {
            [finishedJobs removeObject:jobDescription];
            result = YES;
            break;
        }
    }
    
    [jobsLock unlockWithCondition:[jobsLock condition]];
    
    return result;
}

+ (void)removeAllFinishedJobs
/*" Empties the list of finished jobs. "*/
{
    [jobsLock lock];
    [finishedJobs removeAllObjects];
    [jobsLock unlockWithCondition:[jobsLock condition]];
}

@end
