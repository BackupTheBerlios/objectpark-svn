//
//  TestWithPersistence.m
//  Gina
//
//  Created by Axel Katerbau on 24.12.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import "TestWithPersistence.h"
#import "OPPersistence.h"

@implementation TestWithPersistence

- (void)setUp
{
	[[OPPersistentObjectContext defaultContext] close];
	OPPersistentObjectContext *context = [[OPPersistentObjectContext alloc] init];
	[OPPersistentObjectContext setDefaultContext: context];
	[[NSFileManager defaultManager] removeFileAtPath: @"/tmp/persistent-testobjects.btrees" handler: nil];
	[context setDatabaseFromPath: @"/tmp/persistent-testobjects.btrees"];
}

- (void)tearDown
{
	[[OPPersistentObjectContext defaultContext] close];
	[[NSFileManager defaultManager] removeFileAtPath: @"/tmp/persistent-testobjects.btrees" handler: nil];
}

@end
