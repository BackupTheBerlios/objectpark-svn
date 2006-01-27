//
//  GIMessageGroup+Statistics.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 05.12.05.
//  Copyright 2005 by Objectpark Group. All rights reserved.
//

#import "GIMessageGroup+Statistics.h"
#import "GIMessage.h"

NSString *GINumberOfUnreadMessages = @"GINumberOfUnreadMessages";
NSString *GINumberOfUnreadThreads = @"GINumberOfUnreadThreads";

NSString *GIMessageGroupStatisticsDidInvalidateNotification = @"GIMessageGroupStatisticsDidInvalidateNotification";

@implementation GIMessageGroup (Statistics)

+ (void)initialize
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageFlagsDidChange:) name:GIMessageDidChangeFlagsNotification object:nil];
}

+ (void)messageFlagsDidChange:(NSNotification *)aNotification
{
    NSArray *affectedMessageGroups = [[(GIMessage *)[aNotification object] thread] valueForKey:@"groups"];    
    NSAssert([affectedMessageGroups count] != 0, @"at least one group has to be present");
    
    NSEnumerator *enumerator = [affectedMessageGroups objectEnumerator];
    GIMessageGroup *group;
    
    while (group = [enumerator nextObject])
    {
        [group invalidateStatistics];
    }
}

- (NSNumber *)oidNumber
{
    return [NSNumber numberWithUnsignedLongLong:[self oid]];
}

- (void)didChangeValueForKey:(NSString *)key
{
	[super didChangeValueForKey: key];
	if ([key isEqualToString: @"threadsByDate"]) {
		[self invalidateStatistics];
		[[NSNotificationCenter defaultCenter] postNotificationName: GIMessageGroupStatisticsDidInvalidateNotification object: self];
	}
}

- (NSMutableDictionary *)statistics
{
    NSMutableDictionary *result = [[[[NSUserDefaults standardUserDefaults] objectForKey:[@"GroupStats-" stringByAppendingString:[[self oidNumber] description]]] mutableCopy] autorelease];
    
    if (! result) result = [NSMutableDictionary dictionary];
        
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
    
    [[NSNotificationCenter defaultCenter] postNotificationName:GIMessageGroupStatisticsDidInvalidateNotification object:self];
}

- (NSNumber *)calculateUnreadMessageCount
{
    OPPersistentObjectContext *context = [OPPersistentObjectContext defaultContext];
    NSNumber *unreadMessageCount = nil;
    
    @synchronized(context)
    {
        [context saveChanges];
        
        OPSQLiteStatement *statement = [[[OPSQLiteStatement alloc] initWithSQL: [NSString stringWithFormat:@"select count(*) from Z_4THREADS, ZTHREAD, ZMESSAGE where Z_4THREADS.Z_4GROUPS = %lu and Z_4THREADS.Z_6THREADS = ZTHREAD.Z_PK and ZMESSAGE.ZTHREAD = ZTHREAD.Z_PK and (ZMESSAGE.ZISSEEN = 0 OR ZMESSAGE.ZISSEEN ISNULL);", (unsigned long)[self oid]] connection: [context databaseConnection]] autorelease];
        
        //NSLog(@"%lu", (unsigned long)[self oid]);
        
        [statement execute];
        
        unreadMessageCount = [NSNumber newFromStatement:[statement stmt] index:0];
		
		[statement reset];
    }
    
    return unreadMessageCount;
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
