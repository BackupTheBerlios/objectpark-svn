//
//  TestPersistentStringDictionary.m
//  Gina
//
//  Created by Dirk Theisen on 23.12.07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "TestPersistentStringDictionary.h"
#import "OPPersistentTestObject.h"


@implementation TestPersistentStringDictionary

- (void) setUp
{
	[super setUp];
	dict = [[OPPersistentStringDictionary alloc] init];
	[context setRootObject: (OPPersistentObject*)dict forKey: @"StringDict"];
	[context saveChanges];
}

- (void) testSetSingleObject
{
	OPPersistentTestObject* object = [[OPPersistentTestObject alloc] initWithName: @"object"];
	
	[dict setObject: object forKey: @"key"];
	[context saveChanges];
	[object release]; object = nil;
	
	object = [dict objectForKey: @"key"];
	
	STAssertEqualObjects(object.name, @"object", @"Unable to retrieve same test object from dictionary."); 
	STAssertEquals([dict count], (NSUInteger)1, @"Multiple inserts for the same key should still yield count == 1.");
}

- (void) testSetSingleObject2times
{
	OPPersistentTestObject* object1 = [[OPPersistentTestObject alloc] initWithName: @"object 1"];
	OPPersistentTestObject* object2 = [[OPPersistentTestObject alloc] initWithName: @"object 2"];
	
	[dict setObject: object1 forKey: @"key"];
	[context saveChanges];
	
	[dict setObject: object2 forKey: @"key"];

	
	[object1 release]; object1 = nil;
	[object2 release]; object2 = nil;
	
	OPPersistentTestObject* object = [dict objectForKey: @"key"];
	
	STAssertEqualObjects(object.name, @"object 2", @"Unable to retrieve same test object from dictionary."); 
}

@end
