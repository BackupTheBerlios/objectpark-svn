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
	
	[super dealloc];
}

- (NSObject <NSCopying> *)synchronizedObject
{
	return synchronizedObject;
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
    [jobsLock lock];
	
	OPJob *job = [[[OPJob alloc] initWithName:aName target:aTarget selector:aSelector argument:anArgument synchronizedObject:aSynchronizedObject] autorelease];
        
    [pendingJobs addObject:job];
    
    // start new worker thread if no threads are idle and 
    // the maximum number of worker thread is not reached:
    if (([idleThreads count] == 0) && (threadCount < maxThreads))
    {
        [NSThread detachNewThreadSelector:@selector(workerThread:) toTarget:self withObject:nil];
        threadCount++;
    }
    
    [jobsLock unlockWithCondition:[self nextEligibleJob] ? OPPendingJobs : OPNoPendingJobs];
    
    return job;
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
				                				
                [self performSelectorOnMainThread:@selector(noteJobWillStart:) withObject:job waitUntilDone:NO];
                
                [[job target] performSelector:[job selector] withObject:[job argument]];
            } 
			@catch (NSException *localException) 
			{
				//#warning *** Selector 'isKindOfClass:' sent to dealloced instance 0x5581a80 of class NSException.
                NSLog(@"Job (%@) caused Exception: %@", job, localException);
				[job setException:localException];
            }  
			@finally 
			{
                [jobsLock lock];
                
				[[[NSThread currentThread] threadDictionary] removeObjectForKey:OPJobKey];
                
                [finishedJobs addObject:job];
                [runningJobs removeObject:job];
				
                [self performSelectorOnMainThread:@selector(noteJobDidFinish:) withObject:job waitUntilDone:NO];
                
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

- (NSObject *)result
{
	NSObject *rslt;
	
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

@end
