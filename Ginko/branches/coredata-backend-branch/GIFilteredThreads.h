//
//  GIThreadsDataSource.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 19.07.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class G3MessageGroup;

enum GIThreadFilterMode
{
    markMode,
    hideMode
};

@interface GIFilteredThreads : NSObject 
{
    NSMutableDictionary *properties;
    NSManagedObjectID *groupID;
}

+ (id)filteredThreadsForGroupID:(NSManagedObjectID *)aGroupID;

- (int)filterMode;
- (void)setFilterMode:(int)theFilterMode;

- (NSDate *)ageRestriction;
- (void)setAgeRestriction:(NSDate *)aDate;

- (NSString *)conditions;
- (void)setConditions:(NSString *)someConditions;

- (BOOL)isSortingAscending;
- (void)setSortingAscending:(BOOL)ascending;

- (NSArray *)displayThreads;
- (NSArray *)markThreads;

@end

/*" Indicates that the data source changed (and an update of the corresponding views may make sense). "*/
extern NSString *GIFilteredThreadsDidChangeNotification;