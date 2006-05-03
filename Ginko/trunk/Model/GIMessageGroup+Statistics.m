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

- (void)setUnreadMessageCount:(NSNumber *)aCount
{
    [unreadMessageCount autorelease];
    unreadMessageCount = [aCount retain];
}

+ (void)loadGroupStats
/*" Called at initialization time startup "*/
{
    NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
    NSDictionary* groupStats = [ud objectForKey: @"GroupStats"];
    [ud removeObjectForKey: @"GroupStats"];
    
    NSEnumerator* enumerator = [[self allObjects] objectEnumerator];
    GIMessageGroup* group;
    while (group = [enumerator nextObject]) {
        NSDictionary* stats = [groupStats objectForKey: [group objectURLString]];
        [group setUnreadMessageCount: [stats objectForKey: GINumberOfUnreadMessages]];
    }
}

+ (void)saveGroupStats
/*" Called at the end of the app lifecycle "*/
{
    NSEnumerator *enumerator = [[self allObjects] objectEnumerator];
    GIMessageGroup *group;
    NSMutableDictionary *groupStats = [NSMutableDictionary dictionary];
    
    while (group = [enumerator nextObject])
    {
        NSDictionary *dict = [NSMutableDictionary dictionary];
        NSNumber *unreadCount = [group unreadMessageCount];
        
        NSAssert([unreadCount isKindOfClass:[NSNumber class]], @"shit");
        
        if (unreadCount) [dict setValue:unreadCount forKey:GINumberOfUnreadMessages];
        
        if ([dict count])
        {
            [groupStats setObject:dict forKey:[group objectURLString]];
        }
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:groupStats forKey:@"GroupStats"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (void)initialize
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageFlagsDidChange:) name:GIMessageDidChangeFlagsNotification object:nil];
}

+ (void)messageFlagsDidChange:(NSNotification *)aNotification
{
    NSArray *affectedMessageGroups = [[(GIMessage *)[aNotification object] thread] valueForKey:@"groups"];    
    if ([affectedMessageGroups count] == 0) NSLog(@"warning: flags did change for a message without  being in a group.");
    
	[affectedMessageGroups makeObjectsPerformSelector: @selector(invalidateStatistics)];
}

- (void) didAddValueForKey:(NSString *)key
{
	[super didChangeValueForKey:key];
	if ([key isEqualToString:@"threadsByDate"]) 
    {
		[self invalidateStatistics];
	}
}

- (void) didRemoveValueForKey:(NSString *)key
{
	[super didChangeValueForKey:key];
	if ([key isEqualToString:@"threadsByDate"]) 
    {
		[self invalidateStatistics];
	}
}

- (void)invalidateStatistics
{
    [self setUnreadMessageCount:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:GIMessageGroupStatisticsDidInvalidateNotification object:self];
}

- (NSNumber *)calculateUnreadMessageCount
{
    OPPersistentObjectContext *context = [OPPersistentObjectContext defaultContext];
    NSNumber *result = nil;
    
	
	[context saveChanges];

    @synchronized([context databaseConnection]) {
        
        OPSQLiteStatement *statement = [[[OPSQLiteStatement alloc] initWithSQL: [NSString stringWithFormat:@"select count(*) from Z_4THREADS, ZTHREAD, ZMESSAGE where Z_4THREADS.Z_4GROUPS = %lu and Z_4THREADS.Z_6THREADS = ZTHREAD.Z_PK and ZMESSAGE.ZTHREAD = ZTHREAD.Z_PK and (ZMESSAGE.ZISSEEN = 0 OR ZMESSAGE.ZISSEEN ISNULL);", (unsigned long)[self oid]] connection: [context databaseConnection]] autorelease];
        
        //NSLog(@"%lu", (unsigned long)[self oid]);
        
        [statement execute];
        
        result = [NSNumber newFromStatement:[statement stmt] index:0];
		
		[statement reset];
    }
    
    return result;
}

- (NSNumber *)unreadMessageCount
{
    if (! unreadMessageCount) [self setUnreadMessageCount:[self calculateUnreadMessageCount]];
    return unreadMessageCount;
}

@end
