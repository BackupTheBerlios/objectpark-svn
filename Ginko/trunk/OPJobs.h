//
//  OPJobs.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 22.05.05.
//  Copyright 2005 Objectpark Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface OPJobs : NSObject 
{
}

/*" Scheduling new Jobs "*/
+ (NSNumber *)scheduleJobWithName:(NSString *)aName target:(NSObject *)aTarget selector:(SEL)aSelector arguments:(NSDictionary *)someArguments synchronizedObject:(id <NSCopying>)aSynchronizedObject;

/*" Worker Threads "*/
+ (unsigned)maxThreads;
+ (BOOL)setMaxThreads:(unsigned)newMax;

/*" Statistics "*/
+ (int)idleThreadCount;
+ (int)activeThreadCount;

/*" Inquiring job state "*/
+ (BOOL)isJobPending:(NSNumber *)anJobId;
+ (NSArray *)pendingJobs;
+ (BOOL)isJobRunning:(NSNumber *)anJobId;
+ (NSArray *)runningJobs;
+ (BOOL)isJobFinished:(NSNumber *)anJobId;
+ (NSArray *)finishedJobs;

/*" Cancelling pending jobs "*/
+ (BOOL)cancelPendingJob:(NSNumber *)anJobId;

/*" Handling finished jobs "*/
+ (BOOL)removeFinishedJob:(NSNumber *)anJobId;
+ (void)removeAllFinishedJobs;

/*" Getting job results "*/
+ (id)resultForJob:(NSNumber *)anJobId;

/*" Aborting jobs "*/
+ (BOOL)suggestTerminatingJob:(NSNumber *)anJobId;

/*" Accessing job progress info "*/ 
+ (NSDictionary *)progressInfoForJob:(NSNumber *)anJobId;

/*" Methods for use within jobs "*/
+ (NSNumber *)jobId;
+ (void)setResult:(id)aResult;
+ (BOOL)shouldTerminate;
+ (NSString *)jobName;
+ (void)postNotificationInMainThreadWithName:(NSString *)aNotificationName andUserInfo:(NSMutableDictionary *)userInfo;
+ (NSDictionary *)progressInfoWithMinValue:(double)aMinValue maxValue:(double)aMaxValue currentValue:(double)currentValue description:(NSString *)aDescription;
+ (NSDictionary *)indeterminateProgressInfoWithDescription:(NSString *)aDescription;
+ (void)setProgressInfo:(NSDictionary *)progressInfo;

@end

/*" Notification that a job a about to being executed. object is the job's name and userInfo has a NSNumber object which hold the job's id as an unsigned for the key "jobId". "*/
extern NSString *OPJobWillStartNotification;

/*" Notification that a job has been finished. object is the job's name and userInfo has a NSNumber object which hold the job's id as an unsigned for the key "jobId". "*/
extern NSString *OPJobDidFinishNotification;

/*" Notification that a job has been set its progress information. object is the job's name and userInfo has a NSNumber object which hold the job's id as an unsigned for the key "jobId". The job progress info dictionary is stored for the key "progressInfo". "*/
extern NSString *OPJobDidSetProgressInfoNotification;

extern NSString *OPJobProgressMinValue;
extern NSString *OPJobProgressMaxValue;
extern NSString *OPJobProgressCurrentValue;
extern NSString *OPJobProgressDescription;
extern NSString *OPJobProgressJobName;

@interface NSDictionary (OPJobsExtensions)

- (double)jobProgressMinValue;
- (double)jobProgressMaxValue;
- (double)jobProgressCurrentValue;
- (NSString *)jobProgressDescription;
- (NSString *)jobProgressJobName;
- (BOOL)isJobProgressIndeterminate;

@end