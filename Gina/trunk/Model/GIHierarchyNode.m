//
//  GIHierarchyNode.m
//  BTreeLite
//
//  Created by Dirk Theisen on 07.11.07.
//  Copyright 2007 Dirk Theisen. All rights reserved.
//

#import "GIHierarchyNode.h"
#import "OPFaultingArray.h"
#import "OPPersistence.h"

@implementation GIHierarchyNode

+ (BOOL)cachesAllObjects
{
	return YES;
}

- (void)dealloc
{
	[name release];
	[children release];
    [super dealloc];
}

- (void)willDelete
{
	// delete dependent objects (cascade)
	[children makeObjectsPerformSelector:@selector(willDelete)]; // ask user first!
	[super willDelete];
}

- (BOOL)canHaveChildren
{
	return YES;
}

- (id)init 
{
	if (self = [super init]) 
	{
		NSLog(@"Initialized %@", self);
		if ([self canHaveChildren]) 
		{
			children = [[OPFaultingArray alloc] init];
		}
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
	name = [coder decodeObjectForKey:@"name"];
	children = [coder decodeObjectForKey:@"children"];
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:name forKey:@"name"];
	[coder encodeObject:children forKey:@"children"];
}

- (NSString *)description
{
	return [NSString stringWithFormat:children ? @"%@ '%@' with %u children" : @"%@ '%@'", [super description], [self valueForKey: @"name"], [children count]];
}

- (NSString *)name
{
	return name;
}

- (void)setName:(NSString *)aName
{
	[self willChangeValueForKey:@"name"];
	[name autorelease];
	name = [aName copy];
	[self didChangeValueForKey:@"name"];
}

- (OPFaultingArray *)children
{
	NSLog(@"Requesting children of %@", self);
	return children;
}

- (void) insertObject: (GIHierarchyNode*) node inChildrenAtIndex: (NSUInteger) index
{
	[self willChangeValueForKey: @"children"];
	[children insertObject: node atIndex: index];
	[self didChangeValueForKey: @"children"];
}

- (void) removeObjectFromChildrenAtIndex: (NSUInteger) index
{
	[self willChangeValueForKey: @"children"];
	[children removeObjectAtIndex: index];	
	[self didChangeValueForKey: @"children"];
}

@end

#import "GIMessageGroup.h"

@implementation GIHierarchyNode (MessageGroupHierarchy)

+ (id)messageGroupHierarchyRootNode
{
	OPPersistentObjectContext *context = [OPPersistentObjectContext defaultContext];
	
	static id rootNode = nil;
	
	if (!rootNode) 
	{
		rootNode = [[context rootObjectForKey:@"MessageGroupHierarchyRootNode"] retain];
		if (!rootNode) 
		{
			rootNode = [[self alloc] init];

			[context setRootObject:rootNode forKey:@"MessageGroupHierarchyRootNode"];
		}
	}
	
	return rootNode;
}

- (int)unreadMessageCount
{
	return 0;
}

@end