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
+ (unsigned)scheduleJobWithTarget:(NSObject *)aTarget selector:(SEL)aSelector arguments:(NSDictionary *)someArguments synchronizedObject:(id <NSCopying>)aSynchronizedObject;

/*" Statistics "*/
+ (int)idleThreadCount;
+ (int)activeThreadCount;

/*" Inquiring job state "*/
+ (BOOL)jobIsRunning:(unsigned)anJobId;
+ (BOOL)jobIsFinished:(unsigned)anJobId;
+ (NSArray *)finishedJobs;

/*" Handling finished jobs "*/
+ (BOOL)removeFinishedJob:(unsigned)anJobId;
+ (void)removeAllFinishedJobs;

/*" Getting job results "*/
+ (id)resultForJob:(unsigned)anJobId;

/*" Aborting jobs "*/
+ (BOOL)suggestTerminatingJob:(unsigned)anJobId;

/*" Methods for use within jobs "*/
+ (void)setResult:(id)aResult;
+ (BOOL)shouldTerminate;

@end

/*" Notification that a job a about to being executed. object is a NSNumber object which hold the job's id as an unsigned. "*/
extern NSString *OPJobWillStartNotification;

/*" Notification that a job has been finished. object is a NSNumber object which hold the job's id as an unsigned. "*/
extern NSString *OPJobDidFinishNotification;
