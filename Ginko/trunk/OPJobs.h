//
//  OPJobs.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 22.05.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface OPJobs : NSObject 
{
}

/*" Scheduling new Jobs "*/
+ (unsigned)scheduleJobWithTarget:(NSObject *)aTarget selector:(SEL)aSelector arguments:(NSDictionary *)someArguments synchronizedObject:(id <NSCopying>)aSynchronizedObject;

/*" Inquiring job info "*/
+ (BOOL)jobIsRunning:(unsigned)aJobId;

/*" Jobs engine status "*/
+ (int)idleThreadCount;
+ (int)activeThreadCount;

@end

extern NSString *OPJobId;
extern NSString *OPJobTarget;
extern NSString *OPJobSelector;
extern NSString *OPJobArguments;
extern NSString *OPJobResult;
extern NSString *OPJobUnhandledException;
