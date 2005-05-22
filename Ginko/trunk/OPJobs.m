//
//  OPJobs.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 22.05.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "OPJobs.h"

@implementation OPJobs
/*" Description forthcoming. :-) "*/

enum {OPNoPendingJobs, OPPendingJobs};

NSString *OPJobId = @"OPJobId";
NSString *OPJobTarget = @"OPJobTarget";
NSString *OPJobSelector = @"OPJobSelector";
NSString *OPJobArguments = @"OPJobArguments";
NSString *OPJobResult = @"OPJobResult";
NSString *OPJobUnhandledException = @"OPJobUnhandledException";
NSString *OPJobSynchronizedObject = @"OPJobSynchronizedObject";

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

+ (void)workerThread:(id)args
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
                
                [jobTarget performSelector:jobSelector withObject:jobDescription];
            }
            @catch (NSException *exception) {
                NSLog(@"Job (%@) caused Exception: %@", jobDescription, exception);
                [jobDescription setObject:exception forKey:OPJobUnhandledException];
            }
            @finally {
                [jobsLock lock];
                
                [finishedJobs addObject:jobDescription];
                [runningJobs removeObject:jobDescription];
                
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

+ (BOOL)jobIsRunning:(unsigned)aJobId
{
    BOOL result = NO;
    int i, count;
    
    [jobsLock lock];
    
    count = [runningJobs count];
    for (i = 0; i < count; i++)
    {
        if ([[[runningJobs objectAtIndex:i] objectForKey:OPJobId] unsignedIntValue] == aJobId)
        {
            result = YES;
            break;
        }
    }
    
    [jobsLock unlockWithCondition:[jobsLock condition]];
    
    return result;
}

+ (int)idleThreadCount
{
    int result;
    
    [jobsLock lock];
    result = [idleThreads count];    
    [jobsLock unlockWithCondition:[jobsLock condition]];
    
    return result;
}

+ (int)activeThreadCount
{
    int result;
    
    [jobsLock lock];
    result = [activeThreads count];    
    [jobsLock unlockWithCondition:[jobsLock condition]];
    
    return result;
}

@end
