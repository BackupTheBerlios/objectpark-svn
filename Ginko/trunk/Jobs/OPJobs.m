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
NSString *OPJobDidSetProgressInfoNotification = @"OPJobDidSetProgressInfoNotification";

NSString *OPJobProgressMinValue = @"OPJobProgressMinValue";
NSString *OPJobProgressMaxValue = @"OPJobProgressMaxValue";
NSString *OPJobProgressCurrentValue = @"OPJobProgressCurrentValue";
NSString *OPJobProgressDescription = @"OPJobProgressDescription";
NSString *OPJobProgressJobName = @"OPJobProgressJobName";

enum {OPNoPendingJobs, OPPendingJobs};

NSString *OPJobId = @"OPJobId";
NSString *OPJobName = @"OPJobName";
NSString *OPJobTarget = @"OPJobTarget";
NSString *OPJobSelector = @"OPJobSelector";
NSString *OPJobArguments = @"OPJobArguments";
NSString *OPJobResult = @"OPJobResult";
NSString *OPJobProgressInfo = @"OPJobProgressInfo";
NSString *OPJobUnhandledException = @"OPJobUnhandledException";
NSString *OPJobSynchronizedObject = @"OPJobSynchronizedObject";
NSString *OPJobWorkerThread = @"OPJobWorkerThread";
NSString *OPJobShouldTerminate = @"OPJobShouldTerminate";

static NSConditionLock *jobsLock = nil;

static NSMutableArray *pendingJobs = nil;
static NSMutableArray *runningJobs = nil;
static NSMutableArray *finishedJobs = nil;

static NSMutableSet *synchronizedObjects = nil;

static NSMutableArray *idleThreads = nil;
static NSMutableArray *activeThreads = nil;

static unsigned maxThreads = 2;
static unsigned threadCount = 0;
static unsigned nextJobId = 1;

static BOOL pendingJobsSuspended = NO;

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
    
    if (pendingJobsSuspended) return nil;
    
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

+ (NSNumber *)scheduleJobWithName:(NSString *)aName target:(NSObject *)aTarget selector:(SEL)aSelector arguments:(NSDictionary *)someArguments synchronizedObject:(id <NSCopying>)aSynchronizedObject
/*" Schedules a job for being executed by a worker thread as soon as a unemployed worker thread is present and the execution of this job isn't mutual excluded by a currently running job. 

    aName is an arbitrary name for the job (doesn't need to be unique). This name is used as object when notifications are posted. This way an observer can easily filter by name.

    aTarget is the object on which aSelector will be executed with someArguments as the only argument. 

    aSelector is the selector to call (the method that performs the job).

    someArguments is an dictionary containing arbitrary arguments that can be used by the job.

    aSynchronizedObject may be nil but can be used for excluding other jobs with equal synchronized objects for running at the same time. aSelector must denote a method that takes exactly one parameter of the type #{NSMutableDictionary}. The dictionary holds someArguments (see the source code of the corresponding unit tests for an example). 

    An optional result should be set by invoking #{-setResult:} from within the job. 

    Returns the job's unique id which has to be used for inquiries lateron. "*/
{
    [jobsLock lock];

    NSMutableDictionary *jobDescription = [NSMutableDictionary dictionary];
    NSNumber *jobId = [NSNumber numberWithUnsignedInt:nextJobId++];
    
    [jobDescription setObject:jobId forKey:OPJobId];
    [jobDescription setObject:aName forKey:OPJobName];
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
        [pool release];
        pool = [[NSAutoreleasePool alloc] init];
        
        [jobsLock lockWhenCondition:OPPendingJobs];

        NSMutableDictionary *jobDescription = [self nextPendingJobUnlockingSynchronizedObject:nil];
                        
        // this thread is no longer idle but working:
        [idleThreads removeObject:[NSThread currentThread]];
        [activeThreads addObject:[NSThread currentThread]];
        
        [jobsLock unlockWithCondition:[self nextEligibleJob] ? OPPendingJobs : OPNoPendingJobs];

        while (jobDescription)
        {
            //NSLog(@"Working on job with description: %@", jobDescription);
            ;
            @try 
            {
                // do job here:
                NSObject *jobTarget = [jobDescription objectForKey:OPJobTarget];
                SEL jobSelector = NSSelectorFromString([jobDescription objectForKey:OPJobSelector]);
                
                [jobDescription setObject:[NSThread currentThread] forKey:OPJobWorkerThread];
                                
                [self performSelectorOnMainThread:@selector(noteJobWillStart:) withObject:[jobDescription objectForKey:OPJobId] waitUntilDone:NO];
                
                [jobTarget performSelector:jobSelector withObject:[jobDescription objectForKey:OPJobArguments]];
            } 
            @catch (NSException *localException) 
            {
                [localException retain];
//#warning *** Selector 'isKindOfClass:' sent to dealloced instance 0x5581a80 of class NSException.
                NSLog(@"Job (%@) caused Exception: %@", jobDescription, localException);
                [jobDescription setObject: localException forKey:OPJobUnhandledException];
                [localException autorelease];
            } 
            @finally 
            {
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
            
            [pool release]; pool = [[NSAutoreleasePool alloc] init];
        }
    }
}

static BOOL isJobInArray(NSNumber *anJobId, NSArray *anArray)
{
    BOOL result = NO;
    int i, count;
    
    [jobsLock lock];
    
    count = [anArray count];
    for (i = 0; i < count; i++) 
    {
        if ([[[anArray objectAtIndex:i] objectForKey:OPJobId] isEqualToNumber:anJobId]) 
        {
            result = YES;
            break;
        }
    }
    
    [jobsLock unlockWithCondition:[jobsLock condition]];
    
    return result;
}

+ (BOOL)isJobPending:(NSNumber *)anJobId
/*" Returns YES if the job denoted by anJobId is currently pending. NO otherwise. "*/
{
    return isJobInArray(anJobId, pendingJobs);
}

+ (BOOL)isJobRunning:(NSNumber *)anJobId
/*" Returns YES if the job denoted by anJobId is currently running. NO otherwise. "*/
{
    return isJobInArray(anJobId, runningJobs);
}

+ (BOOL)isJobFinished:(NSNumber *)anJobId
/*" Returns YES if the job denoted by anJobId is in the list of finished jobs. NO otherwise. "*/
{
    return isJobInArray(anJobId, finishedJobs);
}

id objectForKeyInJobInArray(NSNumber *anJobId, NSArray *anArray, NSString *key)
{
    id result = nil;
    int i, count;
    
    [jobsLock lock];
    
    count = [anArray count];
    for (i = count - 1; i >= 0; i--) 
    {
        if ([[[anArray objectAtIndex:i] objectForKey:OPJobId] isEqualToNumber:anJobId]) 
        {
            result = [[anArray objectAtIndex:i] objectForKey:key];
            break;
        }
    }
    
    [jobsLock unlockWithCondition:[jobsLock condition]];
    
    return result;
}

NSArray *jobsRunningForKeyAndObject(NSString *key, id anObject)
{
    int i, count;
    NSMutableArray *result = [NSMutableArray array];
    
    [jobsLock lock];
        
    count = [runningJobs count];
    for (i = count - 1; i >= 0; i--) 
    {
        if ([[[runningJobs objectAtIndex:i] objectForKey:OPJobName] isEqualTo:anObject]) 
        {
            [result addObject:[[runningJobs objectAtIndex:i] objectForKey:OPJobId]];
        }
    }
    
    [jobsLock unlockWithCondition:[jobsLock condition]];
    
    return result;
}

+ (NSArray *)runningJobsWithName:(NSString *)aName
/*" Returns running jobs with the given name aName. "*/
{
    return jobsRunningForKeyAndObject(OPJobName, aName);
}

+ (NSArray *)runningJobsWithSynchronizedObject:(id <NSCopying>)aSynchronizedObject
/*" Returns running jobs with the given synchronized object aSynchronizedObject. "*/
{
    return jobsRunningForKeyAndObject(OPJobSynchronizedObject, aSynchronizedObject);
}

+ (void)noteJobWillStart:(NSNumber *)anJobId
/*" Performed on main thread to notify of the upcoming start of a job. "*/
{
    NSString *jobName = objectForKeyInJobInArray(anJobId, pendingJobs, OPJobName);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:OPJobWillStartNotification object:jobName userInfo:[NSDictionary dictionaryWithObject:anJobId forKey:@"jobId"]];    
}

+ (void)noteJobDidFinish:(NSNumber *)anJobId
/*" Performed on main thread to notifiy of the finishing of a job. "*/
{
    NSString *jobName = objectForKeyInJobInArray(anJobId, finishedJobs, OPJobName);
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    id result = [self resultForJob:anJobId];
    id exception = [self exceptionForJob:anJobId];
    
    if (result) [userInfo setObject:result forKey:@"result"];
    if (exception) [userInfo setObject:exception forKey:@"exception"];
    [userInfo setObject:anJobId forKey:@"jobId"];
    
    
    [[NSNotificationCenter defaultCenter] postNotificationName: OPJobDidFinishNotification object: jobName userInfo: userInfo];
}

+ (id)resultForJob:(NSNumber *)anJobId
/*" Returns the result object for the job denoted by anJobId. nil, if no result was set. "*/
{
    id result;
    
    result = objectForKeyInJobInArray(anJobId, finishedJobs, OPJobResult);
    if (! result) result = objectForKeyInJobInArray(anJobId, runningJobs, OPJobResult);
    
    return result;
}

+ (id)exceptionForJob:(NSNumber *)anJobId
/*" Returns the exception object for the job denoted by anJobId. nil, if no exception was set. "*/
{
    id result;
    
    result = objectForKeyInJobInArray(anJobId, finishedJobs, OPJobUnhandledException);
    
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
            [[runningJobs objectAtIndex:i] setObject:[[aResult copy] autorelease] forKey:OPJobResult];
            break;
        }
    }
    
    [jobsLock unlockWithCondition:[jobsLock condition]];
}

+ (BOOL)shouldTerminate
/*" Returns YES if termination is suggested. NO otherwise. "*/
{
    int i, count;
    NSThread *jobThread = [NSThread currentThread];
    BOOL result = NO;
    
    [jobsLock lock];
    
    count = [runningJobs count];
    for (i = count - 1; i >= 0; i--)
    {
        if ([[runningJobs objectAtIndex:i] objectForKey:OPJobWorkerThread] == jobThread)
        {
            result = [[[runningJobs objectAtIndex:i] objectForKey:OPJobShouldTerminate] boolValue];
            break;
        }
    }
    
    [jobsLock unlockWithCondition:[jobsLock condition]];
    
    return result;
}

id objectForKeyForRunningJob(NSString *key)
{
    id result = nil;
    int i, count;
    NSThread *thread = [NSThread currentThread];
    
    [jobsLock lock];
    
    count = [runningJobs count];
    for (i = count - 1; i >= 0; i--)
    {
        if ([[runningJobs objectAtIndex:i] objectForKey:OPJobWorkerThread] == thread)
        {
            result = [[runningJobs objectAtIndex:i] objectForKey:key];
            break;
        }
    }
    
    [jobsLock unlockWithCondition:[jobsLock condition]];
    
    return result;
}

+ (NSNumber *)jobId
/*" Returns the job's id. "*/
{
    return objectForKeyForRunningJob(OPJobId);
}

+ (NSString *)jobName
/*" Returns the job's name. "*/
{
    return objectForKeyForRunningJob(OPJobName);
}

+ (void)postNotification:(NSNotification *)aNotification;
/*" Called in main thread to post aNotification. "*/
{
    [[NSNotificationCenter defaultCenter] postNotification:aNotification];    
}

+ (void)postNotificationInMainThreadWithName:(NSString *)aNotificationName andUserInfo:(NSMutableDictionary *)userInfo
/*" Helper for jobs. Posts a notification where object is the job's name. The job's id is added to the userInfo dictionary with key @"jobId". "*/
{
    NSNotification *notification;
    NSString *nameObject;
    
    nameObject = [self jobName];
    aNotificationName = [[aNotificationName copy] autorelease];
    [userInfo setObject:[self jobId] forKey:@"jobId"];
    userInfo = [[userInfo copy] autorelease];
    
    notification = [NSNotification notificationWithName:aNotificationName object:nameObject userInfo:userInfo];
    
    [self performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:NO];
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

static NSArray *jobIdsFromArray(NSArray *anArray)
{
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:[anArray count]];
    
    [jobsLock lock];
    NSEnumerator *enumerator = [anArray objectEnumerator];
    NSDictionary *jobDescription;
    
    while (jobDescription = [enumerator nextObject]) 
    {
        [result addObject:[jobDescription objectForKey:OPJobId]];
    }
    
    [jobsLock unlockWithCondition:[jobsLock condition]];
    
    return result;
}

+ (NSArray *)pendingJobs
/*" Returns the job ids of all pending jobs. "*/
{
    return jobIdsFromArray(runningJobs);
}

+ (NSArray *)runningJobs
/*" Returns the job ids of all running jobs. "*/
{
    return jobIdsFromArray(runningJobs);
}

+ (NSArray *)finishedJobs
/*" Returns the job ids of all finished jobs. "*/
{
    return jobIdsFromArray(finishedJobs);
}

BOOL removeJobFromArray(NSNumber *anJobId, NSMutableArray *anArray)
/*" Calling code must lock! "*/
{
    BOOL result = NO;
    int i, count;
    
    count = [anArray count];
    for (i = 0; i < count; i++)
    {
        if ([[[anArray objectAtIndex:i] objectForKey:OPJobId] isEqualToNumber:anJobId])
        {
            result = YES;
            [anArray removeObjectAtIndex:i];
            break;
        }
    }
    
    return result;
}

+ (BOOL)removeFinishedJob:(NSNumber *)anJobId
/*" Removes the job denoted by anJobId including all job information (e.g. the job's result) from the list of finished jobs. "*/
{
    BOOL result;
    
    [jobsLock lock];
    
    result = removeJobFromArray(anJobId, finishedJobs);
    
    [jobsLock unlockWithCondition:[jobsLock condition]];
    
    return result;
}

+ (BOOL)cancelPendingJob:(NSNumber *)anJobId
/*" Cancels the pending job denoted by anJobId. Returns YES if job could be cancelled, NO otherwise. "*/
{
    BOOL result;
    
    [jobsLock lock];
    
    result = removeJobFromArray(anJobId, pendingJobs);
    
    [jobsLock unlockWithCondition:[self nextEligibleJob] ? OPPendingJobs : OPNoPendingJobs];
    
    return result;
}

+ (void)suspendPendingJobs
/*" Suspends all pending jobs. Must be called from the main thread only! "*/
{
    [jobsLock lock];
    
    pendingJobsSuspended = YES;
    
    [jobsLock unlockWithCondition:OPNoPendingJobs];
}

+ (void)resumePendingJobs
/*" Resumes all pending jobs. Must be called from the main thread only! "*/
{
    [jobsLock lock];
    
    pendingJobsSuspended = NO;
    
    [jobsLock unlockWithCondition:[self nextEligibleJob] ? OPPendingJobs : OPNoPendingJobs];
}

+ (void)removeAllFinishedJobs
/*" Empties the list of finished jobs. "*/
{
    [jobsLock lock];
    [finishedJobs removeAllObjects];
    [jobsLock unlockWithCondition:[jobsLock condition]];
}

+ (BOOL)shouldTerminateJob:(NSNumber *)anJobId
/*" Suggests that a job should terminate. While this does not enforce termination of a job denoted by anJobId, the job can see that termination is requested and can do so. Returns YES if the suggestion could be passed on, NO otherwise. "*/
{
    BOOL result = NO;
    
    [jobsLock lock];
    NSEnumerator *enumerator = [runningJobs objectEnumerator];
    NSMutableDictionary *jobDescription;
    
    while (jobDescription = [enumerator nextObject])
    {
        if ([[jobDescription objectForKey:OPJobId] isEqualToNumber:anJobId])
        {
            [jobDescription setObject:[NSNumber numberWithBool:YES] forKey:OPJobShouldTerminate];
            result = YES;
			
#warning OPJobs: Set status string here so that terminating status can be reviewed by the user.
			
            break;
        }
    }
    
    [jobsLock unlockWithCondition:[jobsLock condition]];
    
    return result;
}

+ (BOOL)setMaxThreads:(unsigned)newMax
/*" Sets a new maximum number of worker threads. Lower bound is the current count of created worker threads. Returns YES if the maximum could be set. NO otherwise. "*/
{
    BOOL result = NO;
    
    [jobsLock lock];

    if (newMax >= [activeThreads count])
    {
        result = YES;
        maxThreads = newMax;
    }
    
    [jobsLock unlockWithCondition:[jobsLock condition]];
    
    return result;
}

+ (unsigned)maxThreads
/*" Returns the maximum number of worker threads that may be used. "*/
{
    unsigned result;
    
    [jobsLock lock];
    
    result = maxThreads;
    
    [jobsLock unlockWithCondition:[jobsLock condition]];
    
    return result;
}

+ (NSDictionary *)progressInfoWithMinValue:(double)aMinValue maxValue:(double)aMaxValue currentValue:(double)currentValue description:(NSString *)aDescription
{
    return [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithDouble:aMinValue], OPJobProgressMinValue,
        [NSNumber numberWithDouble:aMaxValue], OPJobProgressMaxValue,
        [NSNumber numberWithDouble:currentValue], OPJobProgressCurrentValue,
        aDescription, OPJobProgressDescription,
        [self jobName], OPJobProgressJobName,
        nil, nil];
}

+ (NSDictionary *)indeterminateProgressInfoWithDescription:(NSString *)aDescription
{
    return [NSDictionary dictionaryWithObjectsAndKeys:
        aDescription, OPJobProgressDescription,
        [self jobName], OPJobProgressJobName,
        nil, nil];
}

+ (void)setProgressInfo:(NSDictionary *)progressInfo
/*" Sets the progress info for the calling job. "*/
{
    int i, count;
    NSThread *jobThread = [NSThread currentThread];
    BOOL setInfo = NO;
    
    progressInfo = [[progressInfo copy] autorelease];
    [jobsLock lock];
    
    count = [runningJobs count];
    for (i = count - 1; i >= 0; i--) 
    {
        if ([[runningJobs objectAtIndex:i] objectForKey:OPJobWorkerThread] == jobThread) 
        {
            [[runningJobs objectAtIndex:i] setObject:progressInfo forKey:OPJobProgressInfo];
            setInfo = YES;
            
            break;
        }
    }

    [jobsLock unlockWithCondition:[jobsLock condition]];
    
    if (setInfo) 
    {
        [self postNotificationInMainThreadWithName:OPJobDidSetProgressInfoNotification andUserInfo:[NSMutableDictionary dictionaryWithObject:progressInfo forKey:@"progressInfo"]];
    }
}

+ (NSDictionary *)progressInfoForJob:(NSNumber *)anJobId
/*" Returns the progress info dictionary for the job denoted by anJobId. nil, if no progress info was set. See #{NSDictinary (OPJobsExtensions)} for easy job progress info access. "*/
{
    id result;
    
    result = objectForKeyInJobInArray(anJobId, runningJobs, OPJobProgressInfo);
    
    return result;
}

@end

@implementation NSDictionary (OPJobsExtensions)

- (double)jobProgressMinValue
{
    NSNumber *result = [self objectForKey:OPJobProgressMinValue];
    return result ? [result doubleValue] : 0.0;
}

- (double)jobProgressMaxValue
{
    NSNumber *result = [self objectForKey:OPJobProgressMaxValue];
    return result ? [result doubleValue] : 0.0;
}

- (double)jobProgressCurrentValue
{
    NSNumber *result = [self objectForKey:OPJobProgressCurrentValue];
    return result ? [result doubleValue] : 0.0;
}

- (NSString *)jobProgressDescription
{
    return [self objectForKey:OPJobProgressDescription];
}

- (BOOL)isJobProgressIndeterminate
{
    return [self objectForKey:OPJobProgressCurrentValue] == nil;
}

- (NSString *)jobProgressJobName
{
    return [self objectForKey:OPJobProgressJobName];    
}

@end

#import "GIAccount.h"
#import "GIPasswordController.h"

@implementation OPJobs (GinkoExtensions)

- (void)openPasswordPanel:(NSMutableDictionary *)someParameters
/*" Called in main thread to open the panel. "*/
{
    [[[GIPasswordController alloc] initWithParamenters:someParameters] autorelease];
}

- (NSString *)runPasswordPanelWithAccount:(GIAccount *)anAccount forIncomingPassword:(BOOL)isIncoming
{
    NSParameterAssert(anAccount != nil);

    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    // prepare parameter dictionary for cross thread method call
    NSMutableDictionary *parameterDict = [NSMutableDictionary dictionary];
    [parameterDict setObject:[NSNumber numberWithBool:isIncoming] forKey:@"isIncoming"];
    [parameterDict setObject:anAccount forKey:@"account"];
    [parameterDict setObject:result forKey:@"result"];
    
    // open panel in main thread
    [self performSelectorOnMainThread:@selector(openPasswordPanel:) withObject:parameterDict waitUntilDone: YES];
    
    NSString *password = nil;
    
    // wait for the panel controller to set an object for key @"finished".
    do
    {
        id finished;
        
        @synchronized(result) 
        {
            finished = [result objectForKey:@"finished"];
            password = [result objectForKey:@"password"];
        }
    
        if (finished) break;
        
        else
        {
            // sleep for 1 second
            //[[NSRunLoop currentRunLoop] run];
            [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
        }
    }
    while (YES);
    
    return password;
}

@end
