//
//  OPJobs.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 22.05.05.
//  Copyright 2005 Objectpark Group. All rights reserved.
//

#import <AppKit/AppKit.h>

#define OPJOBS OPL_DOMAIN @"OPJOBS"

@interface OPJobs : NSObject 
{
}

/*" Scheduling new Jobs "*/
+ (NSNumber *)scheduleJobWithName:(NSString *)aName target:(NSObject *)aTarget selector:(SEL)aSelector argument:(id <NSCopying>)anArgument synchronizedObject:(id <NSCopying>)aSynchronizedObject;

/*" Worker Threads "*/
+ (unsigned)maxThreads;
+ (BOOL)setMaxThreads:(unsigned)newMax;

/*" Statistics "*/
+ (int)idleThreadCount;
+ (int)activeThreadCount;

/*" Inquiring job state "*/
+ (BOOL)isJobPending:(NSNumber *)aJobId;
+ (NSArray *)pendingJobs;
+ (BOOL)isJobRunning:(NSNumber *)aJobId;
+ (NSArray *)runningJobs;
+ (BOOL)isJobFinished:(NSNumber *)aJobId;
+ (NSArray *)finishedJobs;
+ (NSArray *)runningJobsWithName:(NSString *)aName;
+ (NSArray *)pendingJobsWithName:(NSString *)aName;
+ (NSArray *)runningJobsWithSynchronizedObject:(id <NSCopying>)aSynchronizedObject;

/*" Handling pending jobs "*/
+ (BOOL)cancelPendingJob:(NSNumber *)aJobId;
+ (void)suspendPendingJobs;
+ (void)resumePendingJobs;

/*" Handling finished jobs "*/
+ (BOOL)removeFinishedJob:(NSNumber *)aJobId;
+ (void)removeAllFinishedJobs;

/*" Getting job results "*/
+ (id)resultForJob:(NSNumber *)anJobId;

/*" Getting job exeption "*/
+ (id)exceptionForJob:(NSNumber *)anJobId;

/*" Aborting jobs "*/
+ (void)suggestTerminatingJob:(NSNumber *)anJobId;
+ (BOOL)isJobTerminating:(NSNumber *)anJobId;

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

/*" Notification that a job has been finished. object is the job's name and userInfo has a NSNumber object which hold the job's id as an unsigned for the key "jobId". The job's result, if present is stored for the key "result". "*/
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

@class GIAccount;

@interface OPJobs (GinkoExtensions)

- (NSString *)runPasswordPanelWithAccount:(GIAccount *)anAccount forIncomingPassword:(BOOL)isIncoming;

@end
