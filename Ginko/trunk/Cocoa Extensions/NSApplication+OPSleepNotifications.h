//
//  OPSleepNotifications.h
//  Ginko
//
//  Created by Dirk Theisen on Sat Mar 08 2003.
//  Copyright (c) 2003-2006 Dirk Theisen. All rights reserved.
//

#import <AppKit/AppKit.h>

@interface NSApplication (OPSystemSleep)

- (BOOL) willSleep;
- (void) allowSleep: (BOOL) allow;

- (void) applicationShouldSleep;
- (void) applicationDidWakeUp;

@end
