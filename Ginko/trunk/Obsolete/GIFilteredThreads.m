//
//  GIThreadsDataSource.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 19.07.05.
//  Copyright 2005 The Objectpark Group. All rights reserved.
//

#import "GIFilteredThreads.h"


@implementation GIFilteredThreads

- (id)initWithGroupID: (NSURL*) aGroupID
{
    self = [super init];
    
    groupID = [aGroupID retain];
        
    return self;
}

static NSMutableDictionary *filteredThreadsForGroupID = nil;

+ (id) filteredThreadsForGroupID: (NSURL*) aGroupID
{
    if (! filteredThreadsForGroupID) filteredThreadsForGroupID = [[NSMutableDictionary alloc] initWithCapacity:7];
    
    id result = [filteredThreadsForGroupID objectForKey: aGroupID];
    
    if (! result) {
        result = [[self alloc] initWithGroupID: aGroupID];
        [filteredThreadsForGroupID setObject: result forKey: aGroupID];
        [result release];
    }
    
    return result;
}

- (NSMutableDictionary *)properties
{
    NSString *defaultsKey = [[groupID absoluteString] stringByAppendingString:@"-FilteredThreadProperties"];
    
    if (! properties) properties = [[[NSUserDefaults standardUserDefaults] objectForKey:defaultsKey] mutableCopy];
    if (! properties) properties = [[NSMutableDictionary alloc] init];
    
    return properties;
}

- (void) commitProperties
{
    NSString *defaultsKey = [[groupID absoluteString] stringByAppendingString:@"-FilteredThreadProperties"];
    
    [[NSUserDefaults standardUserDefaults] setObject: [self properties] forKey:defaultsKey];
}

- (id)propertyForName: (NSString*) aName
{
    return [[self properties] objectForKey:aName];
}

- (void) setProperty:(id)aProperty forName: (NSString*) aName
{
    if (aProperty) [[self properties] setObject: aProperty forKey:aName];
    else [[self properties] removeObjectForKey:aName];
    
    [self commitProperties];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void) dealloc
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

- (void) setFilterMode:(int)theFilterMode
{
    [self setProperty:[NSNumber numberWithInt:theFilterMode] forName:@"Mode"];
}

- (NSDate*) ageRestriction
{
    return [self propertyForName:@"AgeRestriction"];
}

- (void) setAgeRestriction:(NSDate*) aDate
{
    [self setProperty:aDate forName:@"AgeRestriction"];
}

- (NSString*) conditions
{
    return [self propertyForName:@"Conditions"];
}

- (void) setConditions: (NSString*) someConditions
{
    [self setProperty:someConditions forName:@"Conditions"];
}

- (BOOL)isSortingAscending
{
    return [[self propertyForName:@"IsAscending"] boolValue];
}

- (void) setSortingAscending:(BOOL)ascending
{
    [self setProperty:[NSNumber numberWithBool:ascending] forName:@"IsAscending"];
}

- (NSArray*) displayThreads
{
    NSMutableArray *conditions = [NSMutableArray array];
    
    NSDate *ageRestriction = [self ageRestriction];
    if (ageRestriction) [conditions addObject:[NSString stringWithFormat:@"ZTHREAD.ZDATE >= %f", [ageRestriction timeIntervalSinceReferenceDate]]];
    
    NSString *additionalConditions = [self conditions];
    if (additionalConditions) [conditions addObject:additionalConditions];
    
    BOOL ascending = [self isSortingAscending];
    
    NSString *queryString = [NSString stringWithFormat:@"select Z_PK, ZNUMBEROFMESSAGES from Z_4THREADS, ZTHREAD where %@ order by ZTHREAD.ZDATE %@;", [conditions componentsJoinedByString:@" and "], ascending ? @"ASC" : @"DESC"];
    
    return nil;
    
}
    /*
- (NSArray*) markThreads;
    */

@end
