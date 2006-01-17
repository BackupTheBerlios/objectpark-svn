//
//  GIMessageGroup+Statistics.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 05.12.05.
//  Copyright 2005 by Objectpark Group. All rights reserved.
//

#import "GIMessageGroup+Statistics.h"

NSString* GINumberOfUnreadMessages = @"GINumberOfUnreadMessages";
NSString* GINumberOfUnreadThreads = @"GINumberOfUnreadThreads";

NSString* GIMessageGroupStatisticsDidChangeNotification = @"GIMessageGroupStatisticsDidChangeNotification";

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

- (NSNumber *)calculateUnreadMessageCount
{
    OPSQLiteStatement *statement = [[[OPSQLiteStatement alloc] initWithSQL:[NSString stringWithFormat:@"select count(*) from Z_4THREADS, ZTHREAD, ZMESSAGE where Z_4THREADS.Z_4GROUPS = %lu and Z_4THREADS.Z_6THREADS = ZTHREAD.Z_PK and ZMESSAGE.ZTHREAD = ZTHREAD.Z_PK and (ZMESSAGE.ZISSEEN = 0 OR ZMESSAGE.ZISSEEN ISNULL);", (unsigned long)[self oid]] connection:[[OPPersistentObjectContext defaultContext] databaseConnection]] autorelease];
    
    //NSLog(@"%lu", (unsigned long)[self oid]);
    
    [statement execute];
    
    NSNumber *unreadMessages = [NSNumber newFromStatement:[statement stmt] index:0];
    
    return unreadMessages;
}

@end
