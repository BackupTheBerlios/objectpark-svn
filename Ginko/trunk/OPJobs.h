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
+ (unsigned)scheduleJobWithName:(NSString *)aName target:(NSObject *)aTarget selector:(SEL)aSelector arguments:(NSDictionary *)someArguments synchronizedObject:(id <NSCopying>)aSynchronizedObject;

/*" Worker Threads "*/
+ (unsigned)maxThreads;
+ (BOOL)setMaxThreads:(unsigned)newMax;

/*" Statistics "*/
+ (int)idleThreadCount;
+ (int)activeThreadCount;

/*" Inquiring job state "*/
+ (BOOL)isJobPending:(unsigned)anJobId;
+ (NSArray *)pendingJobs;
+ (BOOL)isJobRunning:(unsigned)anJobId;
+ (NSArray *)runningJobs;
+ (BOOL)isJobFinished:(unsigned)anJobId;
+ (NSArray *)finishedJobs;

/*" Cancelling pending jobs "*/
+ (BOOL)cancelPendingJob:(unsigned)anJobId;

/*" Handling finished jobs "*/
+ (BOOL)removeFinishedJob:(unsigned)anJobId;
+ (void)removeAllFinishedJobs;

/*" Getting job results "*/
+ (id)resultForJob:(unsigned)anJobId;

/*" Aborting jobs "*/
+ (BOOL)suggestTerminatingJob:(unsigned)anJobId;

/*" Methods for use within jobs "*/
+ (NSNumber *)jobId;
+ (void)setResult:(id)aResult;
+ (BOOL)shouldTerminate;
+ (NSString *)jobName;
+ (void)postNotificationInMainThreadWithName:(NSString *)aNotificationName andUserInfo:(NSMutableDictionary *)userInfo;

@end

/*" Notification that a job a about to being executed. object is the job's name and userInfo has a NSNumber object which hold the job's id as an unsigned for the key "jobId". "*/
extern NSString *OPJobWillStartNotification;

/*" Notification that a job has been finished. object is a NSNumber object which hold the job's id as an unsigned.object is the job's name and userInfo has a NSNumber object which hold the job's id as an unsigned for the key "jobId". "*/
extern NSString *OPJobDidFinishNotification;
