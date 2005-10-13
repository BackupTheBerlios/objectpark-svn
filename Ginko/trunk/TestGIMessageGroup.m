//
//  TestGIMessageGroup.m
//  GinkoVoyagerGIThread
//
//  Created by Axel Katerbau on 17.05.05.
//  Copyright (c) 2005 Objectpark Group. All rights reserved.
//

#import "TestGIMessageGroup.h"
#import "GIMessageGroup.h"
#import "GIThread.h"
#import "OPPersistentObject+Extensions.h"

@implementation TestGIMessageGroup

- (void)testStandardGroups
{
    GIMessageGroup *group1, *group2;
    
    group1 = [GIMessageGroup defaultMessageGroup];
    group2 = [GIMessageGroup defaultMessageGroup];
    
    STAssertTrue([group1 isEqual:group2], @"Duplicate default group.");
}

- (void)testDefaultGroup
{
    GIMessageGroup *tempDefaultGroup;
    
    tempDefaultGroup = [GIMessageGroup defaultMessageGroup];
    
    STAssertTrue(tempDefaultGroup != nil, @"should not be nil");
    
    //STAssertEqualObjects([tempDefaultGroup name], @"Default Inbox", @"Name of default group is not 'Default Inbox' but '%@'", [tempDefaultGroup name]);
}

- (void)testThreadIdsByDate
{
    NSMutableArray *result = [NSMutableArray array];
        
    NSEnumerator *enumerator = [result objectEnumerator];
    NSString *urlString;
    NSManagedObjectContext *context = [NSManagedObjectContext threadContext];
    
    while (urlString = [enumerator nextObject])
    {
        STAssertTrue([context objectWithURI:[NSURL URLWithString:urlString]] != nil, @"Url %@ failed.", urlString);
    }
    
    //NSLog(@"First Thread's name '%@'", [(GIThread *)[[NSManagedObjectContext threadContext] objectWithURI:[NSURL URLWithString:[result objectAtIndex:4]]] valueForKey:@"subject"]);
}

@end
