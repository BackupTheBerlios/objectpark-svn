//
//  TestGIMessageGroup.m
//  Gina
//
//  Created by Axel Katerbau on 24.12.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import "TestGIMessageGroup.h"
#import "GIMessageGroup.h"
#import "GIThread.h"
#import "TestGIThread.h"

@implementation TestGIMessageGroup

- (void)testGroupThreadRelationship1
{
	GIMessageGroup *group = [[[GIMessageGroup alloc] init] autorelease];
	GIThread *thread = [TestGIThread threadForTest];
	
	[[group mutableSetValueForKey: @"threads"] addObject: thread];
	NSAssert([thread.messageGroups containsObject: group], @"inverse relaionship not set.");
}

- (void)testGroupThreadRelationship2
{
	GIMessageGroup *group = [[[GIMessageGroup alloc] init] autorelease];
	GIThread *thread = [TestGIThread threadForTest];
	
	[[thread mutableArrayValueForKey: @"messageGroups"] addObject: group];
	NSAssert([group.threads containsObject: thread], @"inverse relaionship not set.");
}

- (void) observeValueForKeyPath: (NSString*) keyPath ofObject: (id) object change: (NSDictionary*) change context:(void*) context
{
	NSArray* oldValues = [change objectForKey: NSKeyValueChangeOldKey];
	NSAssert(oldValues.count, @"NSKeyValueChangeOldKey not set.");
	//[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}


- (void) testHierarchyObservation
{
	GIHierarchyNode* parent = [[GIHierarchyNode alloc] init];
	GIHierarchyNode* child = [[GIHierarchyNode alloc] init];
	
	[[parent mutableArrayValueForKey: @"children"] addObject: child];
	
	[parent addObserver: self forKeyPath: @"children" options: NSKeyValueObservingOptionNew |
	 NSKeyValueObservingOptionOld context: nil];
	
	[[parent mutableArrayValueForKey: @"children"] removeObject: child];
	
	[parent removeObserver: self forKeyPath: @"children"];
	[parent release];
}

@end
