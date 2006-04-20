//
//  OPSleepNotifications.m
//  Ginko
//
//  Created by Dirk Theisen on Sat Mar 08 2003.
//  Copyright (c) 2003-2006 Dirk Theisen. All rights reserved.
//

#import "NSApplication+OPSleepNotifications.h"
#include <CoreFoundation/CoreFoundation.h>

#include <IOKit/pwr_mgt/IOPMLib.h>
#include <IOKit/IOMessage.h>

@interface OPSleepNotifications: NSObject
@end

@implementation OPSleepNotifications

+ (void) load
{
    [super load];
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(applicationDidFinishLaunching:)
                                                 name: NSApplicationWillFinishLaunchingNotification
                                               object: nil];

    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(applicationWillTerminate:)
                                                 name: NSApplicationWillTerminateNotification
                                               object: nil];
}



static BOOL willSleep = NO;
static io_connect_t root_port = 0;
static long notificationID = 0;

void sleepCallback(void * x,io_service_t y,natural_t messageType,void * messageArgument)
{
    printf("Got messageType %08lx, arg %08lx\n",(long unsigned int)messageType, (long unsigned int)messageArgument);

    notificationID = (long)messageArgument;

    switch ( messageType ) {
        case kIOMessageSystemWillSleep:
            // Handle demand sleep (such as sleep caused by running out of
            // batteries, closing the lid of a laptop, or selecting
            // sleep from the Apple menu.

            //IOAllowPowerChange(root_port,(long)messageArgument);
            //IOCancelPowerChange(root_port,(long)messageArgument); // calling this sleeps immediately
            // calling none of the two above waits for 30 seconds.
			willSleep = YES;

        case kIOMessageCanSystemSleep:
            // In this case, the computer has been idle for several minutes
            // and will sleep soon so you must either allow or cancel
            // this notification. Important: if you don't respond, there will
            // be a 30-second timeout before the computer sleeps.
        {
            [NSApp applicationShouldSleep];
            break;
        }
        case kIOMessageSystemHasPoweredOn:
        {
            // Handle wakeup:
			notificationID = 0;
			willSleep = NO;
            [NSApp applicationDidWakeUp];
            break;
        }
    }
}

static io_object_t powernotifier;


+ (void) applicationDidFinishLaunching: (NSNotification*) notification
{
    IONotificationPortRef portRef;

    root_port = IORegisterForSystemPower (0,&portRef,sleepCallback,&powernotifier);
    if ( root_port == 0 ) {
        NSLog(@"Warning: IORegisterForSystemPower failed. Sleep notifications will not work.");
    }

    CFRunLoopAddSource(CFRunLoopGetCurrent(),
                       IONotificationPortGetRunLoopSource(portRef),
                       kCFRunLoopDefaultMode);

}

+ (void) applicationWillTerminate: (NSNotification*) notification
{
	// Cleanup at program termination time.
    IODeregisterForSystemPower(&powernotifier);
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}



@end


@implementation NSApplication (OPSystemSleep)

- (BOOL) willSleep
{
    return willSleep;
}

- (void) allowSleep: (BOOL) allow
/*" If called without prior applicationShouldSleep notification, die nothing. "*/
{
    if (root_port && notificationID) {
        if (allow) {
            IOAllowPowerChange(root_port, notificationID);
        } else {
			if (![self willSleep]) {
				IOCancelPowerChange(root_port, notificationID); // calling this with willSleep==YES, sleeps immediately! :-O
			}
        }
        NSLog(@"- allowSleep: %d executed.", allow);
    }
}

- (void) applicationShouldSleep
/*" Called before the computer enters sleep mode. The default implementation calls allowSleep: YES. The delegate can implement -applicationWillSleep: to set allowSleep: NO. If -willSleep returns YES, this will delay (30 sec), otherwise prevent the sleep. "*/
{
    SEL delegateMethod = @selector(applicationShouldSleep:);
    if ([[self delegate] respondsToSelector: delegateMethod])
        [[self delegate] performSelector: delegateMethod withObject: self];
    else
        [self allowSleep: YES]; // assume nobody is handling the sleep request
}

- (void) applicationDidWakeUp
/*" Called after the computer woke up from sleep mode. The default implementation does nothing. The application delegate can implement -applicationWillSleep: in order to re-initialize internal state etc. "*/
{
    SEL delegateMethod = @selector(applicationDidWakeUp:);
    if ([[self delegate] respondsToSelector: delegateMethod])
        [[self delegate] performSelector: delegateMethod withObject: self];
	NSLog(@"- applicationDidWakeUp executed.");

}

@end

