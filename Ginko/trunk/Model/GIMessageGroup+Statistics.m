//
//  GIMessageGroup+Statistics.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 05.12.05.
//  Copyright 2005 by Objectpark Group. All rights reserved.
//

#import "GIMessageGroup+Statistics.h"

NSString *GINumberOfUnreadMessages = @"GINumberOfUnreadMessages";
NSString *GINumberOfUnreadThreads = @"GINumberOfUnreadThreads";

NSString *GIMessageGroupStatisticsDidChangeNotification = @"GIMessageGroupStatisticsDidChangeNotification";

@implementation GIMessageGroup (Statistics)

static NSMutableDictionary *allGroupStats = nil;

- (NSMutableDictionary *)allGroupStats
{
    if (!allGroupStats) allGroupStats = [[NSMutableDictionary alloc] init];
    return allGroupStats;
}

- (NSNumber *)oidNumber
{
    return [NSNumber numberWithUnsignedLongLong:[self oid]];
}

- (NSDictionary *)statistics
{
    NSDictionary *result = nil;
    
    @synchronized(allGroupStats)
    {
        result = [[[[self allGroupStats] objectForKey:[self oidNumber]] copy] autorelease];
    }
    
    return result;
}

- (void)invalidateStatistics
{
    @synchronized(allGroupStats)
    {
        [[self allGroupStats] removeObjectForKey:[self oidNumber]];
    }
}

- (void)calculateStatisticsAndNotify
{
    
}

@end
