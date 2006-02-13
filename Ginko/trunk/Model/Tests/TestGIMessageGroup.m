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
#import "OPPersistentObjectContext.h"

@implementation TestGIMessageGroup

/*
- (void) testStandardGroups
{
    GIMessageGroup *group1, *group2;
    
    group1 = [GIMessageGroup defaultMessageGroup];
    group2 = [GIMessageGroup defaultMessageGroup];
    
    STAssertTrue([group1 isEqual:group2], @"Duplicate default group.");
}

- (void) testDefaultGroup
{
    GIMessageGroup *tempDefaultGroup;
    
    tempDefaultGroup = [GIMessageGroup defaultMessageGroup];
    
    STAssertTrue(tempDefaultGroup != nil, @"should not be nil");
    
    //STAssertEqualObjects([tempDefaultGroup name], @"Default Inbox", @"Name of default group is not 'Default Inbox' but '%@'", [tempDefaultGroup name]);
}
*/

- (void)testThreadIdsByDate
{
    NSMutableArray *result = [NSMutableArray array];
        
    NSEnumerator *enumerator = [result objectEnumerator];
    NSString *urlString;
    OPPersistentObjectContext *myContext = [OPPersistentObjectContext threadContext];
    
    while (urlString = [enumerator nextObject])
    {
        STAssertTrue([myContext objectWithURLString: urlString] != nil, @"Url %@ failed.", urlString);
    }
    
    //NSLog(@"First Thread's name '%@'", [(GIThread *)[[NSManagedObjectContext threadContext] objectWithURI:[NSURL URLWithString:[result objectAtIndex:4]]] valueForKey: @"subject"]);
}

- (void)testGroupRemove
{
    GIMessageGroup *group = [[GIMessageGroup alloc] init];
    OID groupOID = [group oid];
    [context saveChanges];
    
    group = [context objectForOid:groupOID ofClass:[GIMessageGroup class]];
    STAssertTrue(group != nil, @"group not persistent");
    
    [group delete];
    [context saveChanges];

    group = [context objectForOid:groupOID ofClass:[GIMessageGroup class]];
    STAssertFalse([group resolveFault], @"group still persistent with old context");
    
    context = nil;
    [self setUp];
    
    group = [context objectForOid:groupOID ofClass:[GIMessageGroup class]];
    STAssertFalse([group resolveFault], @"group still persistent with new context");
}

@end
