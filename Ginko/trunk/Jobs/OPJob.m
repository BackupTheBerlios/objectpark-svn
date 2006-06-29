//
//  OPJob.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 05.05.06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "OPJob.h"

@implementation OPJob

enum {OPNoPendingJobs, OPPendingJobs};

static NSConditionLock *jobsLock = nil;

static NSMutableArray *pendingJobs = nil;
static NSMutableArray *runningJobs = nil;
static NSMutableArray *finishedJobs = nil;

static NSMutableSet *synchronizedObjects = nil;

static NSMutableArray *idleThreads = nil;
static NSMutableArray *activeThreads = nil;

static unsigned maxThreads = 2;
static unsigned threadCount = 0;

static BOOL pendingJobsSuspended = NO;

static NSString *OPJobKey = @"OPJob";

NSString *JobProgressMinValue = @"OPJobProgressMinValue";
NSString *JobProgressMaxValue = @"OPJobProgressMaxValue";
NSString *JobProgressCurrentValue = @"OPJobProgressCurrentValue";
NSString *JobProgressDescription = @"OPJobProgressDescription";
NSString *JobProgressJob = @"OPJobProgressJob";

NSString *JobWillStartNotification = @"OPJobWillStartNotification";
NSString *JobDidFinishNotification = @"OPJobDidFinishNotification";
NSString *JobDidSetProgressInfoNotification = @"OPJobDidSetProgressInfoNotification";

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

// Worker Threads
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

- (id)initWithName:(NSString *)aName target:(NSObject *)aTarget selector:(SEL)aSelector argument:(NSObject <NSCopying> *)anArgument synchronizedObject:(NSObject <NSCopying> *)aSynchronizedObject
{
	self = [super init];
	
	NSParameterAssert(aName != nil);
	NSParameterAssert(aTarget != nil);
	NSParameterAssert(aSelector != NULL);
	
	name = [aName retain];
	target = [aTarget retain];
	selector = aSelector;
	argument = [anArgument copyWithZone:[self zone]];
	synchronizedObject = [aSynchronizedObject copyWithZone:[self zone]];
	
	return self;
}

- (void)dealloc
{
	[name release];
	[target release];
	[argument release];
	[synchronizedObject release];
	[progressInfo release];
	
	[super dealloc];
}

- (NSObject <NSCopying> *)synchronizedObject
{
	return synchronizedObject;
}

- (NSString *)name
{
	return [[name copy] autorelease]; 
}

- (NSObject <NSCopying> *)argument
{
	return argument;
}

- (SEL)selector
{
	return selector;
}

- (NSObject *)target
{
	return target;
}

- (void)setException:(NSException *)anException
{
	@synchronized(self)
	{
		[anException retain];
		[exception release];
		exception = anException;
	}
}

- (id)exception
/*" Returns the exception for the receiver. nil, if no exception was set. "*/
{
	NSException *rslt;
	
	@synchronized(self) 
	{
		rslt = [[exception copy] autorelease];
	}
	
	return rslt;
}

- (NSDictionary *)progressInfo
/*" Returns the progress info dictionary for the job denoted by anJobId. nil, if no progress info was set. See #{NSDictinary (OPJobsExtensions)} for easy job progress info access. "*/
{
	NSDictionary *rslt;
	
	@synchronized(self)
	{
		rslt = [[progressInfo copy] autorelease];
	}
	
	return rslt;
}

+ (OPJob *)nextEligibleJob
/*" Returns the next job that is allowed to run. Caution: Run locked only! "*/
{
    OPJob *result = nil;
    
    if (pendingJobsSuspended) return nil;
    
    int count = [pendingJobs count];
    if (count)
    {
        int i; 
        for (i = 0; i < count; i++)
        {
            OPJob *job = [pendingJobs objectAtIndex:i];
            id synchronizedObject = [job synchronizedObject];
            
            if (synchronizedObject)
            {
                if(![synchronizedObjects containsObject:synchronizedObject])
                {
                    result = job;
                    break;
                }
            }
            else
            {
                result = job;
                break;
            }
        }
    }
    
    //NSLog(@"nextEligibleJob = %@", result);
    return result;
}

+ (OPJob *)nextPendingJobUnlockingSynchronizedObject:(id)anSynchronizedObject
/*" Returns the next eligile job description. Removes synchronization of anSynchroniziedObject (may be nil). Sets the job in running state. Caution: Run locked only! "*/
{
    OPJob *result = nil;
    
    if (anSynchronizedObject)
    {
        [synchronizedObjects removeObject:anSynchronizedObject];
    }
    
    result = [self nextEligibleJob];
    
    if (result)
    {
        id synchronizedObject = [result synchronizedObject];
        
        if (synchronizedObject)
        {
            [synchronizedObjects addObject:synchronizedObject];
        }
        
        [runningJobs addObject:result];
        [pendingJobs removeObject:result];
    }
    
    return result;
}

+ (OPJob *)scheduleJobWithName:(NSString *)aName target:(NSObject *)aTarget selector:(SEL)aSelector argument:(NSObject <NSCopying> *)anArgument synchronizedObject:(NSObject <NSCopying> *)aSynchronizedObject
/*" Schedules a job for being executed by a worker thread as soon as a unemployed worker thread is present and the execution of this job isn't mutual excluded by a currently running job. 

    aName is an arbitrary name for the job (doesn't need to be unique). This name is used as object when notifications are posted. This way an observer can easily filter by name.

    aTarget is the object on which aSelector will be executed with someArguments as the only argument. 

    aSelector is the selector to call (the method that performs the job).

    anArgument is an arbitrary object that can be used by the job.

    aSynchronizedObject may be nil but can be used for excluding other jobs with equal synchronized objects for running at the same time. aSelector must denote a method that takes exactly one parameter of the type #{NSMutableDictionary}. The dictionary holds someArguments (see the source code of the corresponding unit tests for an example). 

    An optional result should be set by invoking #{-setResult:} from within the job. 

    Returns the job or nil if not successful. "*/
{
	
	OPJob *job = [[[OPJob alloc] initWithName:aName target:aTarget selector:aSelector argument:anArgument synchronizedObject:aSynchronizedObject] autorelease];
        
    [self scheduleJob:job];
	
    return job;
}

+ (void)scheduleJob:(OPJob *)job
{
    [jobsLock lock];
	
    [pendingJobs addObject:job];
    
    // start new worker thread if no threads are idle and 
    // the maximum number of worker thread is not reached:
    if (([idleThreads count] == 0) && (threadCount < maxThreads))
    {
        [NSThread detachNewThreadSelector:@selector(workerThread:) toTarget:self withObject:nil];
        threadCount++;
    }
	
    [jobsLock unlockWithCondition:[self nextEligibleJob] ? OPPendingJobs : OPNoPendingJobs];
}

+ (void)workerThread:(id)args
/*" The worker threads' detached method. "*/
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    [jobsLock lock];
    
    [idleThreads addObject:[NSThread currentThread]];
    //NSLog(@"Thread %@ started:", [NSThread currentThread]);
    
    [jobsLock unlockWithCondition:[self nextEligibleJob] ? OPPendingJobs : OPNoPendingJobs];
    
    while (YES) 
	{
        [pool release];
        pool = [[NSAutoreleasePool alloc] init];
        
        [jobsLock lockWhenCondition:OPPendingJobs];
		
        OPJob *job = [self nextPendingJobUnlockingSynchronizedObject:nil];
		
        // this thread is no longer idle but working:
        [idleThreads removeObject:[NSThread currentThread]];
        [activeThreads addObject:[NSThread currentThread]];
        
        [jobsLock unlockWithCondition:[self nextEligibleJob] ? OPPendingJobs : OPNoPendingJobs];
		
        while (job) 
		{;
            //NSLog(@"Working on job with description: %@", jobDescription);
			@try 
			{
                // do job here:
				[[[NSThread currentThread] threadDictionary] setObject:job forKey:OPJobKey];
				                			
				NSNotification *jobWillStartNotification = [NSNotification notificationWithName:JobWillStartNotification object:job];
				
                [self postNotificationInMainThread:jobWillStartNotification];
                
                [[job target] performSelector:[job selector] withObject:[job argument]];
            } 
			@catch (id localException) 
			{
				//#warning *** Selector 'isKindOfClass:' sent to dealloced instance 0x5581a80 of class NSException.
				[job setException:localException];
                NSLog(@"Job (%@) caused Exception: %@", job, localException);
            }  
			@finally 
			{
                [jobsLock lock];
                
				[[[NSThread currentThread] threadDictionary] removeObjectForKey:OPJobKey];
                
                [finishedJobs addObject:job];
                [runningJobs removeObject:job];
				
				NSNotification *jobDidFinishNotification = [NSNotification notificationWithName:JobDidFinishNotification object:job];
				
                [self postNotificationInMainThread:jobDidFinishNotification];
				                
                // try to get next job:
                job = [self nextPendingJobUnlockingSynchronizedObject:[job synchronizedObject]];
                
                if (! job) 
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

+ (OPJob *)job
/*" Returns the current thread's job. "*/
{
	return [[[NSThread currentThread] threadDictionary] objectForKey:OPJobKey];
}

// Handling finished jobs

+ (BOOL)removeFinishedJob:(OPJob *)aJob
/*" Removes aJob from the list of finished jobs. Returns YES if the job was 
	finished and could be removed. NO otherwise. "*/
{
    BOOL result;
    
    [jobsLock lock];
    
	result = [finishedJobs containsObject:aJob];
    [finishedJobs removeObject:aJob];
		
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

// Handling pending jobs

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

+ (BOOL)cancelPendingJob:(OPJob *)aJob
/*" Cancels the pending job aJob. Returns YES if job could be cancelled, NO otherwise. "*/
{
    BOOL result;
    
    [jobsLock lock];
    
	result = [pendingJobs containsObject:aJob];
    [pendingJobs removeObject:aJob];
    
    [jobsLock unlockWithCondition:[self nextEligibleJob] ? OPPendingJobs : OPNoPendingJobs];
    
    return result;
}


// Statistics

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

+ (NSArray *)pendingJobs
/*" Returns the job ids of all pending jobs. "*/
{
	NSArray *result;
	
	[jobsLock lock];
    result = [[pendingJobs copy] autorelease];    
    [jobsLock unlockWithCondition:[jobsLock condition]];
	
	return result;
}

+ (NSArray *)runningJobs
/*" Returns the job ids of all running jobs. "*/
{
	NSArray *result;
	
	[jobsLock lock];
    result = [[runningJobs copy] autorelease];    
    [jobsLock unlockWithCondition:[jobsLock condition]];
	
	return result;
}

+ (NSArray *)finishedJobs
/*" Returns the job ids of all finished jobs. "*/
{
	NSArray *result;
	
	[jobsLock lock];
    result = [[finishedJobs copy] autorelease];    
    [jobsLock unlockWithCondition:[jobsLock condition]];
	
	return result;
}

+ (NSArray *)jobsWithValue:(NSObject *)aValue forKey:(NSString *)aKey inArray:(NSArray *)anArray
{
	NSMutableArray *result = [NSMutableArray array];
	
	[jobsLock lock];
	NSEnumerator *enumerator = [anArray objectEnumerator];
	OPJob *job;
	
	while (job = [enumerator nextObject])
	{
		if ([[job valueForKey:aKey] isEqual:aValue])
		{
			[result addObject:job];
		}
	}
	
	[jobsLock unlockWithCondition:[jobsLock condition]];
	
	return result;
}

+ (NSArray *)runningJobsWithName:(NSString *)aName
/*" Returns running jobs with the given name aName. "*/
{
	return [self jobsWithValue:aName forKey:@"name" inArray:runningJobs];
}

+ (NSArray *)pendingJobsWithName:(NSString *)aName
/*" Returns pending jobs with the given name aName. "*/
{
	return [self jobsWithValue:aName forKey:@"name" inArray:pendingJobs];
}

+ (NSArray *)pendingJobsWithTarget:(NSObject *)aTarget
/*" Returns pending jobs with the given target aTarget. "*/
{
	return [self jobsWithValue:aTarget forKey:@"target" inArray:pendingJobs];
}
									
+ (NSArray *)runningJobsWithSynchronizedObject:(NSObject <NSCopying> *)aSynchronizedObject
/*" Returns running jobs with the given synchronized object aSynchronizedObject. "*/
{
	return [self jobsWithValue:aSynchronizedObject forKey:@"synchronizedObject" inArray:runningJobs];
}

// Job state accessors
- (BOOL)isPending
/*" Returns YES if the job denoted by anJobId is currently pending. NO otherwise. "*/
{
	BOOL rslt;
	
	[jobsLock lock];
	rslt = [pendingJobs containsObject:self];
	[jobsLock unlockWithCondition:[jobsLock condition]];
	
	return rslt;
}

- (BOOL)isRunning
/*" Returns YES if the job denoted by anJobId is currently running. NO otherwise. "*/
{
	BOOL rslt;
	
	[jobsLock lock];
	rslt = [runningJobs containsObject:self];
	[jobsLock unlockWithCondition:[jobsLock condition]];
	
	return rslt;
}

- (BOOL)isFinished
/*" Returns YES if the job denoted by anJobId is in the list of finished jobs. NO otherwise. "*/
{
	BOOL rslt;
	
	[jobsLock lock];
	rslt = [finishedJobs containsObject:self];
	[jobsLock unlockWithCondition:[jobsLock condition]];
	
	return rslt;
}

- (BOOL)isTerminating
/*" Returns YES if the running job with the id anJobId has been suggested to terminate. "*/
{
	BOOL rslt;
	
	@synchronized(self)
	{
		rslt = shouldTerminate;
	}
	
	return rslt;
}

- (id)result
{
	id rslt;
	
	@synchronized(self)
	{
		rslt = [[result copy] autorelease];
	}
	
	return rslt;
}


- (void)setResult:(NSObject *)aResult
{
	@synchronized(self)
	{
		if (aResult != result) 
		{
			[result release];
			result = [aResult copy];
		}
	}
}

- (BOOL)shouldTerminate
{
	BOOL rslt;
	
	@synchronized(self)
	{
		rslt = shouldTerminate;
	}
	
	return rslt;
}

- (void)suggestTerminating
{
	@synchronized(self)
	{
		shouldTerminate = YES;
	}
}

+ (void)postNotificationInMainThread:(NSNotification *)aNotification
/*" Helper for jobs. Posts a notification in main thread. "*/
{
    [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:[[aNotification copy] autorelease] waitUntilDone:NO];
}

- (NSDictionary *)progressInfoWithMinValue:(double)aMinValue maxValue:(double)aMaxValue currentValue:(double)currentValue description:(NSString *)aDescription
{
    return [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithDouble:aMinValue], JobProgressMinValue,
        [NSNumber numberWithDouble:aMaxValue], JobProgressMaxValue,
        [NSNumber numberWithDouble:currentValue], JobProgressCurrentValue,
        aDescription, JobProgressDescription,
        self, JobProgressJob,
        nil, nil];
}

- (NSDictionary *)indeterminateProgressInfoWithDescription:(NSString *)aDescription
{
    return [NSDictionary dictionaryWithObjectsAndKeys:
        aDescription, JobProgressDescription,
        self, JobProgressJob,
        nil, nil];
}

- (void)setProgressInfo:(NSDictionary *)aProgressInfo
/*" Sets the progress info for the calling job. "*/
{
	BOOL wasSet = NO;
	
	@synchronized(self)
	{
		if (! [progressInfo isEqual:aProgressInfo])
		{
			[progressInfo release];
			progressInfo = [aProgressInfo copy];
			wasSet = YES;
		}
	}
    
    if (wasSet && progressInfo) 
    {
		NSNotification *notification = [NSNotification notificationWithName:JobDidSetProgressInfoNotification object:self userInfo:[NSDictionary dictionaryWithObject:progressInfo forKey:@"progressInfo"]];
		
		[[self class] postNotificationInMainThread:notification];
    }
}

// Miscellaneous
- (BOOL)isHidden
{
	BOOL rslt;
	
	@synchronized(self)
	{
		rslt = isHidden;
	}
	
	return rslt;
}

- (void)setHidden:(BOOL)shouldBeHidden
{
	@synchronized(self)
	{
		isHidden = shouldBeHidden;
	}
}

@end

#import "GIAccount.h"
#import "GIPasswordController.h"

@implementation OPJob (GinkoExtensions)

- (void)openPasswordPanel:(NSMutableDictionary *)someParameters
	/*" Called in main thread to open the panel. "*/
{
    [[[GIPasswordController alloc] initWithParamenters:someParameters] autorelease];
}

- (NSString *)runPasswordPanelWithAccount:(GIAccount *)anAccount forIncomingPassword:(BOOL)isIncoming
{
    NSParameterAssert(anAccount != nil);
	
    NSMutableDictionary *rslt = [NSMutableDictionary dictionary];
    // prepare parameter dictionary for cross thread method call
    NSMutableDictionary *parameterDict = [NSMutableDictionary dictionary];
    [parameterDict setObject:[NSNumber numberWithBool:isIncoming] forKey:@"isIncoming"];
    [parameterDict setObject:anAccount forKey:@"account"];
    [parameterDict setObject:rslt forKey:@"result"];
    
    // open panel in main thread
    [self performSelectorOnMainThread:@selector(openPasswordPanel:) withObject:parameterDict waitUntilDone:YES];
    
    NSString *password = nil;
    
    // wait for the panel controller to set an object for key @"finished".
    do
    {
        id finished;
        
        @synchronized(rslt) 
        {
            finished = [rslt objectForKey:@"finished"];
            password = [rslt objectForKey:@"password"];
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

@implementation NSDictionary (OPJobExtensions)

- (double)jobProgressMinValue
{
    NSNumber *rslt = [self objectForKey:JobProgressMinValue];
    return rslt ? [rslt doubleValue] : 0.0;
}

- (double)jobProgressMaxValue
{
    NSNumber *rslt = [self objectForKey:JobProgressMaxValue];
    return rslt ? [rslt doubleValue] : 0.0;
}

- (double)jobProgressCurrentValue
{
    NSNumber *rslt = [self objectForKey:JobProgressCurrentValue];
    return rslt ? [rslt doubleValue] : 0.0;
}

- (NSString *)jobProgressDescription
{
    return [self objectForKey:JobProgressDescription];
}

- (BOOL)isJobProgressIndeterminate
{
    return [self objectForKey:JobProgressCurrentValue] == nil;
}

- (OPJob *)jobProgressJob
{
    return [self objectForKey:JobProgressJob];    
}

@end
