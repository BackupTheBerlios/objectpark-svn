//
//  OPersistenceTests.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 24.07.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "TestPersistence.h"
#import "OPPersistence.h"
#import "GIMessage.h"

@implementation TestPersistence

- (void) setUp
{
    context = [OPPersistentObjectContext defaultContext];

    if (![context databaseConnection]) {
        
        [context setDatabaseConnectionFromPath: [NSHomeDirectory() stringByAppendingPathComponent: @"Application Support/GinkoVoyager/GinkoBase.sqlite"]];
        
    } else {
        [context reset];
    }
    
}

- (void) tearDown
{
    
}

- (void) testSimpleFaulting
{
    OID testOid = [OPPersistentObjectContext oidForLid: 1 class: [GIMessage class]];
    GIMessage* message = [context objectForOid: testOid];
    NSLog(@"Got first message fault: %@", message);
}

@end
