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
        
        [context setDatabaseConnectionFromPath: [NSHomeDirectory() stringByAppendingPathComponent: @"Library/Application Support/GinkoVoyager/GinkoBase.sqlite"]];
        
    } else {
        [context reset];
    }
    
}

- (void) tearDown
{
    
}

- (void) testSimpleFaulting
{
    OID testOid = 2;
    GIMessage* message = [context objectForOid: testOid ofClass: [GIMessage class]];
    NSLog(@"Got message fault: %@", message);
    [message resolveFault];
    NSLog(@"Got message: %@", message);
	
	[[message valueForKey: @"profile"] resolveFault];
	
	NSLog(@"Message fas profile: %@", [message valueForKey: @"profile"]);


}

@end
