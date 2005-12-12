//
//  GIMessageGroup+Statistics.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 05.12.05.
//  Copyright 2005 by Objectpark Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GIMessageGroup.h"

@interface GIMessageGroup (Statistics)

- (NSDictionary *)statistics;
- (void)invalidateStatistics;

- (void)calculateStatisticsAndNotify;

@end

extern NSString *GINumberOfUnreadMessages;
extern NSString *GINumberOfUnreadThreads;

extern NSString *GIMessageGroupStatisticsDidChangeNotification;