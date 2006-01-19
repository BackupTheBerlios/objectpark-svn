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

NSString *GIMessageGroupStatisticsDidInvalidateNotification = @"GIMessageGroupStatisticsDidInvalidateNotification";

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

- (void)observeValueForKeyPath:(NSString *)keyPath 
                      ofObject:(id)object 
                        change:(NSDictionary *)change 
                       context:(void *)context
{
    if (object == self) 
    {
        if ([keyPath isEqualToString:@"threadsByDate"])
        {
            [self invalidateStatistics];
            [[NSNotificationCenter defaultCenter] postNotificationName:GIMessageGroupStatisticsDidInvalidateNotification object:self];
        }
    }
}

- (NSMutableDictionary *)statistics
{
    NSMutableDictionary *result = [[NSUserDefaults standardUserDefaults] objectForKey:[@"GroupStats-" stringByAppendingString:[[self oidNumber] description]]];
    
    if (! result) result = [NSMutableDictionary dictionary];
    
    // add as observer:
    [self addObserver:self 
           forKeyPath:@"threadsByDate" 
              options:NSKeyValueObservingOptionNew 
              context:NULL];
        
    return result;
}

- (void)setStatistics:(NSDictionary *)aDict
{
    [[NSUserDefaults standardUserDefaults] setObject:aDict forKey:[@"GroupStats-" stringByAppendingString:[[self oidNumber] description]]];
}

- (void)invalidateStatistics
{
    NSMutableDictionary *stats = [self statistics];
    [stats removeAllObjects];
    [self setStatistics:stats];
}

- (NSNumber *)calculateUnreadMessageCount
{
    OPPersistentObjectContext *context = [OPPersistentObjectContext defaultContext];
    NSNumber *unreadMessages = nil;
    
    @synchronized(context)
    {
        OPSQLiteStatement *statement = [[[OPSQLiteStatement alloc] initWithSQL:[NSString stringWithFormat:@"select count(*) from Z_4THREADS, ZTHREAD, ZMESSAGE where Z_4THREADS.Z_4GROUPS = %lu and Z_4THREADS.Z_6THREADS = ZTHREAD.Z_PK and ZMESSAGE.ZTHREAD = ZTHREAD.Z_PK and (ZMESSAGE.ZISSEEN = 0 OR ZMESSAGE.ZISSEEN ISNULL);", (unsigned long)[self oid]] connection:[context databaseConnection]] autorelease];
        
        //NSLog(@"%lu", (unsigned long)[self oid]);
        
        [statement execute];
        
        unreadMessages = [NSNumber newFromStatement:[statement stmt] index:0];
    }
    
    return unreadMessages;
}

- (NSNumber *)unreadMessageCount
{
    NSMutableDictionary *stats = [self statistics];
    NSNumber *result = [stats objectForKey:GINumberOfUnreadMessages];
    if (! result) 
    {
        result = [self calculateUnreadMessageCount];
        [stats setObject:result forKey:GINumberOfUnreadMessages];
        [self setStatistics:stats];
    }
    return result;
}

@end
