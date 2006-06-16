//
//  GIMessageGroup+Statistics.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 05.12.05.
//  Copyright 2005 by Objectpark Group. All rights reserved.
//

#import "GIMessageGroup+Statistics.h"
#import "GIMessage.h"
#import "OPJob.h"
#import "GIThread.h"

NSString *GINumberOfUnreadMessages = @"GINumberOfUnreadMessages";
NSString *GINumberOfUnreadThreads = @"GINumberOfUnreadThreads";

NSString *GIMessageGroupStatisticsDidInvalidateNotification = @"GIMessageGroupStatisticsDidInvalidateNotification";
NSString *GIMessageGroupStatisticsDidUpdateNotification = @"GIMessageGroupStatisticsDidUpdateNotification";

@implementation GIMessageGroup (Statistics)

- (void)setUnreadMessageCount:(NSNumber *)aCount
{
	@synchronized(self)
	{
		[unreadMessageCount autorelease];
		unreadMessageCount = [aCount retain];
	}
}

+ (void)loadGroupStats
/*" Called at initialization time startup "*/
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *groupStats = [userDefaults objectForKey:@"GroupStats"];
    [userDefaults removeObjectForKey:@"GroupStats"];
    
    NSEnumerator *enumerator = [[self allObjects] objectEnumerator];
    GIMessageGroup *group;
    while (group = [enumerator nextObject]) 
	{;
		@synchronized(group)
		{
			NSDictionary *stats = [groupStats objectForKey:[group objectURLString]];
			NSNumber *numberOfUnreadMessages = [stats objectForKey:GINumberOfUnreadMessages];
			if (numberOfUnreadMessages)
			{
				//NSLog(@"set number of unread messages");
				[group setUnreadMessageCount:numberOfUnreadMessages];
				group->isStatisticsValid = YES;
			}
		}
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
        NSNumber *unreadCount = group->unreadMessageCount;
        
        NSAssert(!unreadCount || [unreadCount isKindOfClass:[NSNumber class]], @"shit");
        
        if (unreadCount && group->isStatisticsValid) [dict setValue:unreadCount forKey:GINumberOfUnreadMessages];
        
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

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(threadDidChange:) name:GIThreadDidChangeNotification object:nil];
}

+ (void)messageFlagsDidChange:(NSNotification *)aNotification
{
    NSArray *affectedMessageGroups = [[(GIMessage *)[aNotification object] thread] valueForKey:@"groups"];    
    if ([affectedMessageGroups count] == 0) NSLog(@"warning: flags did change for a message without group.");
    
	[affectedMessageGroups makeObjectsPerformSelector:@selector(invalidateStatistics)];
}

+ (void)threadDidChange:(NSNotification *)aNotification
{
    NSArray *affectedMessageGroups = [(GIThread *)[aNotification object] valueForKey:@"groups"];    
    if ([affectedMessageGroups count] == 0) NSLog(@"warning: thread did change for a thread without group.");
    
	NSLog(@"threadDidChange for groups: %@", affectedMessageGroups);

	[affectedMessageGroups makeObjectsPerformSelector:@selector(invalidateStatistics)];
}

- (void)didAddValueForKey:(NSString *)key
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
	@synchronized(self)
	{
		isStatisticsValid = NO;
	}
	
	NSNotification *notification = [NSNotification notificationWithName:GIMessageGroupStatisticsDidInvalidateNotification object:self];
	[[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:NO];
}

- (NSString *)jobName
{
	return @"Group Statistics Update";
}

- (void)calculateUnreadMessageCount
{
	//NSLog(@"Starting statistics job for group %@", self);
	
	OPJob *job = [[[OPJob alloc] initWithName:[self jobName] target:self selector:@selector(calculateUnreadMessageCountJob:) argument:[NSDictionary dictionaryWithObject:self forKey:@"group"] synchronizedObject:[NSNumber numberWithUnsignedLongLong:[self oid]]] autorelease];

	[job setHidden:YES];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(statisticsJobDidEnd:) name:JobDidFinishNotification object:job];
	
	[OPJob scheduleJob:job];
}

- (NSNumber *)unreadMessageCount
{
	@synchronized(self)
	{
		if (!isStatisticsValid)
		{
			if (![[OPJob pendingJobsWithTarget:self] count])
			{
				[self calculateUnreadMessageCount];
			}
			isStatisticsValid = YES;
		}
	}
    return unreadMessageCount;
}

- (void)statisticsJobDidEnd:(NSNotification *)aNotification
{		
	OPJob *job = [aNotification object];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:JobDidFinishNotification object:job];
	
	NSNumber *result = [job result];
	
	//NSLog(@"Finished statistics Job for group %@ with result %@.", self, result);

	[self setUnreadMessageCount:result];
	
	NSNotification *notification = [NSNotification notificationWithName:GIMessageGroupStatisticsDidUpdateNotification object:self];
	[[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:NO];
}

- (void)calculateUnreadMessageCountJob:(NSDictionary *)arguments
{
    OPPersistentObjectContext *context = [OPPersistentObjectContext defaultContext];
	
	[context saveChanges];
	
    @synchronized([context databaseConnection]) 
	{
        OPSQLiteStatement *statement = [[[OPSQLiteStatement alloc] initWithSQL:[NSString stringWithFormat:@"select count(*) from Z_4THREADS, ZTHREAD, ZMESSAGE where Z_4THREADS.Z_4GROUPS = %lu and Z_4THREADS.Z_6THREADS = ZTHREAD.Z_PK and ZMESSAGE.ZTHREAD = ZTHREAD.Z_PK and (ZMESSAGE.ZISSEEN = 0 OR ZMESSAGE.ZISSEEN ISNULL);", (unsigned long)[self oid]] connection:[context databaseConnection]] autorelease];
        
        //NSLog(@"%lu", (unsigned long)[self oid]);
        
        [statement execute];
        
		[[OPJob job] setResult:[NSNumber newFromStatement:[statement stmt] index:0]];
		
		[statement reset];
    }
}

@end
