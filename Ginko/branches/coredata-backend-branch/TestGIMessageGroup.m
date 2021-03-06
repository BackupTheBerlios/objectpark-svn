//
//  TestGIMessageGroup.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 17.05.05.
//  Copyright (c) 2005 Objectpark Group. All rights reserved.
//

#import "TestGIMessageGroup.h"
#import "G3MessageGroup.h"
#import "G3Thread.h"
#import "NSManagedObjectContext+Extensions.h"

@implementation TestGIMessageGroup

- (void)testStandardGroups
{
    G3MessageGroup *group1, *group2;
    
    group1 = [G3MessageGroup defaultMessageGroup];
    group2 = [G3MessageGroup defaultMessageGroup];
    
    STAssertTrue([group1 isEqual:group2], @"Duplicate default group.");
}

- (void)testDefaultGroup
{
    G3MessageGroup *tempDefaultGroup;
    
    tempDefaultGroup = [G3MessageGroup defaultMessageGroup];
    
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
    
    //NSLog(@"First Thread's name '%@'", [(G3Thread *)[[NSManagedObjectContext threadContext] objectWithURI:[NSURL URLWithString:[result objectAtIndex:4]]] valueForKey:@"subject"]);
}

@end
