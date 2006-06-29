//
//  TestNSArray+Extensions.m
//  GinkoVoyager
//
//  Created by Jörg Westheide on 01.02.06.
//  Copyright (c) 2006 Objectpark.org. All rights reserved.
//

#import "TestNSArray+Extensions.h"
#import "NSArray+Extensions.h"


@implementation TestNSArrayExtensions

- (void) testRemoveDuplicates_NothingToDo
{
    NSMutableArray* a = [NSMutableArray arrayWithObjects:@"0", @"1", @"2", nil];
    
    [a removeDuplicates];
    
    int count = [a count];
    
    STAssertEquals(count, 3, @"The number of entries was modified");
    
    STAssertEqualObjects([a objectAtIndex:0], @"0", @"Entry at index 0 was modified");
    STAssertEqualObjects([a objectAtIndex:1], @"1", @"Entry at index 1 was modified");
    STAssertEqualObjects([a objectAtIndex:2], @"2", @"Entry at index 2 was modified");
}


- (void) testRemoveDuplicates_uniqueAtTheStart
{
    NSMutableArray* a = [NSMutableArray arrayWithObjects:@"0", @"0", @"1", nil];
    
    [a removeDuplicates];
    
    int count = [a count];
    STAssertEquals(count, 2, @"The number of entries is wrong");
    
    STAssertEqualObjects([a objectAtIndex:0], @"0", @"Entry at index 0 is wrong");
    STAssertEqualObjects([a objectAtIndex:1], @"1", @"Entry at index 1 is wrong");
}


- (void) testRemoveDuplicates_uniqueAtTheEnd
{
    NSMutableArray* a = [NSMutableArray arrayWithObjects:@"0", @"1", @"1", nil];
    
    [a removeDuplicates];
    
    int count = [a count];
    STAssertEquals(count, 2, @"The number of entries is wrong");
    
    STAssertEqualObjects([a objectAtIndex:0], @"0", @"Entry at index 0 is wrong");
    STAssertEqualObjects([a objectAtIndex:1], @"1", @"Entry at index 1 is wrong");
}


- (void) testRemoveDuplicates_uniqueInTheMiddle
{
    NSMutableArray* a = [NSMutableArray arrayWithObjects:@"0", @"1", @"1", @"2", nil];
    
    [a removeDuplicates];
    
    int count = [a count];
    STAssertEquals(count, 3, @"The number of entries is wrong");
    
    STAssertEqualObjects([a objectAtIndex:0], @"0", @"Entry at index 0 is wrong");
    STAssertEqualObjects([a objectAtIndex:1], @"1", @"Entry at index 1 is wrong");
    STAssertEqualObjects([a objectAtIndex:2], @"2", @"Entry at index 2 is wrong");
}


- (void) testRemoveDuplicates_multipleDuplicates
{
    NSMutableArray* a = [NSMutableArray arrayWithObjects:@"0", @"1", @"0", @"0", @"0", @"0", @"1", @"2", @"1", @"1", @"0", @"2", @"2", @"1", @"1", nil];
    
    [a removeDuplicates];
    
    int count = [a count];
    STAssertEquals(count, 3, @"The number of entries is wrong");
    
    STAssertEqualObjects([a objectAtIndex:0], @"0", @"Entry at index 0 is wrong");
    STAssertEqualObjects([a objectAtIndex:1], @"1", @"Entry at index 1 is wrong");
    STAssertEqualObjects([a objectAtIndex:2], @"2", @"Entry at index 2 is wrong");
}




@end
