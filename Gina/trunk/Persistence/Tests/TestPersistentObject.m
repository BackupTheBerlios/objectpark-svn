//
//  Test-PersistentObject.m
//  Gina
//
//  Created by Dirk Theisen on 21.12.07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "TestPersistentObject.h"


@implementation TestPersistentObject


- (void) setUp
{
	NSLog(@"Hello, persistent World!");

	context = [[OPPersistentObjectContext alloc] init];
	[OPPersistentObjectContext setDefaultContext: context];
	[[NSFileManager defaultManager] removeFileAtPath: @"/tmp/persistent-testobjects.btrees" handler: nil];
	[context setDatabaseFromPath: @"/tmp/persistent-testobjects.btrees"];
		
	[context saveChanges];
}



- (void) tearDown
{
	[context saveChanges];
	[context close];
	[context release]; context = nil;
}

@end
