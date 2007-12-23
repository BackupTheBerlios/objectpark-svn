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

- (void) testSetSingleObjectSet
{
	OPPersistentTestObject* object = [[OPPersistentTestObject alloc] initWithName: @"object 1"];
	
	[dict setObject: object forKey: @"key 1"];
	[context saveChanges];
	[object release]; object = nil;
	
	object = [dict objectForKey: @"key 1"];
	
	STAssertEqualObjects(object.name, @"object 1", @"Unable to retrieve same test object from dictionary."); 
}

@end
