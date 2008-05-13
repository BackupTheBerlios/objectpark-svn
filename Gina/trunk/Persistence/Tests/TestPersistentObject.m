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

- (void) testMultiElementSet
{	
	NSMutableArray* elements = [NSMutableArray array];
	for (int i=0; i<100; i++) {
		OPPersistentTestObject* newElement = [[OPPersistentTestObject alloc] initWithName: [NSString stringWithFormat: @"Element %04u", i]];
		[[o1 mutableSetValueForKey: @"bunch"] addObject: newElement];

		NSAssert1([o1.bunch member: newElement] == newElement, @"%@ not added.", newElement);
		[elements addObject: newElement];
	}	
	
	[context saveChanges];
	
}


- (void) testSingleElementSet
{
	OPPersistentTestObject* newElement = [[OPPersistentTestObject alloc] initWithName: @"newElement"];

	[[o1 mutableSetValueForKey: @"bunch"] addObject: newElement];
	
	NSAssert(o1.bunch.anyObject == newElement, @"newElement not added.");
	NSAssert([o1.bunch member: newElement] == newElement, @"newElement not added.");
	
	[[o1 mutableSetValueForKey: @"bunch"] removeObject: newElement];
	
	NSAssert(o1.bunch.anyObject == nil, @"newElement not removed.");
	NSAssert(o1.bunch.count == 0, @"newElement not removed.");
	NSAssert([o1.bunch member: newElement] == nil, @"newElement not removed.");

	[[o1 mutableSetValueForKey: @"bunch"] addObject: newElement];
	NSAssert([o1.bunch member: newElement] == newElement, @"newElement not added again.");

	
	[context saveChanges];
	
	[newElement release];
}

@end
