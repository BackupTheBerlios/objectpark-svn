//
//  GIThreadsDataSource.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 19.07.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "GIFilteredThreads.h"


@implementation GIFilteredThreads

- (id)initWithGroupID:(NSManagedObjectID *)anGroupID
{
    self = [super init];
    
    groupID = [anGroupID retain];
        
    return self;
}

static NSMutableDictionary *filteredThreadsForGroupID = nil;

+ (id)filteredThreadsForGroupID:(NSManagedObjectID *)aGroupID
{
    if (! filteredThreadsForGroupID) filteredThreadsForGroupID = [[NSMutableDictionary alloc] initWithCapacity:7];
    
    id result = [filteredThreadsForGroupID objectForKey:aGroupID];
    
    if (! result) 
    {
        result = [[self alloc] initWithGroupID:aGroupID];
        [filteredThreadsForGroupID setObject:result forKey:aGroupID];
        [result release];
    }
    
    return result;
}

- (NSMutableDictionary *)properties
{
    NSString *defaultsKey = [[[groupID URIRepresentation] absoluteString] stringByAppendingString:@"-FilteredThreadProperties"];
    
    if (! properties) properties = [[[NSUserDefaults standardUserDefaults] objectForKey:defaultsKey] mutableCopy];
    if (! properties) properties = [[NSMutableDictionary alloc] init];
    
    return properties;
}

- (void)commitProperties
{
    NSString *defaultsKey = [[[groupID URIRepresentation] absoluteString] stringByAppendingString:@"-FilteredThreadProperties"];
    
    [[NSUserDefaults standardUserDefaults] setObject:[self properties] forKey:defaultsKey];
}

- (id)propertyForName:(NSString *)aName
{
    
    return [[self properties] objectForKey:aName];
}

- (void)setProperty:(id)aProperty forName:(NSString *)aName
{
    if (aProperty) [[self properties] setObject:aProperty forKey:aName];
    else [[self properties] removeObjectForKey:aName];
    
    [self commitProperties];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)dealloc
{
    [properties release];
    [groupID release];

    [super dealloc];
}

// accessors
- (int)filterMode
{
    return [[self propertyForName:@"Mode"] intValue];
}

- (void)setFilterMode:(int)theFilterMode
{
    [self setProperty:[NSNumber numberWithInt:theFilterMode] forName:@"Mode"];
}

- (NSDate *)ageRestriction
{
    return [self propertyForName:@"AgeRestriction"];
}

- (void)setAgeRestriction:(NSDate *)aDate
{
    [self setProperty:aDate forName:@"AgeRestriction"];
}

- (NSString *)filterQuery
{
    return [self propertyForName:@"Query"];
}

- (void)setFilterQuery:(NSString *)aQuery
{
    [self setProperty:aQuery forName:@"Query"];
}

- (BOOL)isSortingAscending
{
    return [[self propertyForName:@"IsAscending"] boolValue];
}

- (void)setSortingAscending:(BOOL)ascending
{
    [self setProperty:[NSNumber numberWithBool:ascending] forName:@"IsAscending"];
}

/*
- (NSArray *)displayThreads;
- (NSArray *)markThreads;
*/

@end
