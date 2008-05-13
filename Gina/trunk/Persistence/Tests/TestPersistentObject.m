//
//  Test-PersistentObject.m
//  Gina
//
//  Created by Dirk Theisen on 21.12.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
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
		
	o1 = [[OPPersistentTestObject alloc] init];
	[context insertObject: o1];
	
	[context saveChanges];
	
	[o1 release];
}



- (void) tearDown
{
	[context saveChanges];
	[context close];
	[context release]; context = nil;
}

- (void) testSet
{
	OPPersistentTestObject* newElement = [[OPPersistentTestObject alloc] init];
	newElement.name = @"newElement";

	[[o1 mutableSetValueForKey: @"bunch"] addObject: newElement];
	
	NSAssert(o1.bunch.anyObject == newElement, @"newElement not added.");
	
	[newElement release];
}

@end
