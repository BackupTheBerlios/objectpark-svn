//
//  OPJob.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 05.05.06.
//  Copyright 2006 Objectpark Group. All rights reserved.
//

#import <Foundation/Foundation.h>

#define OPJOB OPL_DOMAIN @"OPJOB"

@interface OPJob : NSObject 
{
	@private
	NSString *name;
	SEL selector;
	NSObject *target;
	NSObject <NSCopying> *argument;
	NSObject <NSCopying> *synchronizedObject;
	NSException *exception;
	NSObject *result;
	BOOL shouldTerminate;
}

/*" Scheduling new Jobs "*/
+ (OPJob *)scheduleJobWithName:(NSString *)aName target:(NSObject *)aTarget selector:(SEL)aSelector argument:(NSObject <NSCopying> *)anArgument synchronizedObject:(NSObject <NSCopying> *)aSynchronizedObject;

/*" Worker Threads "*/
+ (unsigned)maxThreads;
+ (BOOL)setMaxThreads:(unsigned)newMax;

/*" Statistics "*/
+ (int)idleThreadCount;
+ (int)activeThreadCount;

+ (NSArray *)pendingJobs;
+ (NSArray *)runningJobs;
+ (NSArray *)finishedJobs;

+ (NSArray *)runningJobsWithName:(NSString *)aName;
+ (NSArray *)pendingJobsWithName:(NSString *)aName;
+ (NSArray *)runningJobsWithSynchronizedObject:(id <NSCopying>)aSynchronizedObject;

/*" Handling pending jobs "*/
+ (void)suspendPendingJobs;
+ (void)resumePendingJobs;

/*" Handling finished jobs "*/
+ (BOOL)removeFinishedJob:(OPJob *)aJob;
+ (void)removeAllFinishedJobs;

/*" Job state accessors "*/
- (BOOL)isPending;
- (BOOL)isRunning;
- (BOOL)isFinished;
- (BOOL)isTerminating;

/*" Job operations "*/
- (BOOL)cancel;
- (NSObject *)result;
- (id)exception;
- (void)suggestTerminating;
- (NSDictionary *)progressInfo;

/*" Methods for use within jobs "*/
+ (OPJob *)job;
- (void)setResult:(NSObject *)aResult;
- (BOOL)shouldTerminate;
- (NSString *)name;
- (void)postNotificationInMainThreadWithName:(NSString *)aNotificationName andUserInfo:(NSMutableDictionary *)userInfo;
- (NSDictionary *)progressInfoWithMinValue:(double)aMinValue maxValue:(double)aMaxValue currentValue:(double)currentValue description:(NSString *)aDescription;
- (NSDictionary *)indeterminateProgressInfoWithDescription:(NSString *)aDescription;
- (void)setProgressInfo:(NSDictionary *)progressInfo;

@end
