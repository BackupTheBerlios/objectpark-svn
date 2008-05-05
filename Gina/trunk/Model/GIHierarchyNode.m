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

NSString *GIHierarchyChangedNotification = @"GIHierarchyChangedNotification";

@implementation GIHierarchyNode

+ (BOOL)cachesAllObjects
{
	return YES;
}

- (void)noteHierarchyChanged
{
	[[NSNotificationCenter defaultCenter] postNotificationName:GIHierarchyChangedNotification object:self];
}

- (void)dealloc
{
	[name release];
	[children release];
	[self noteHierarchyChanged];
	
    [super dealloc];
}

//- (void)willDelete
//{
//	// delete dependent objects (cascade)
//	[super willDelete];
//}

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
	name     = [[coder decodeObjectForKey:@"name"] retain];
	children = [[coder decodeObjectForKey:@"children"] retain];
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:name forKey:@"name"];
	[coder encodeObject: children forKey:@"children"];
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
	
	[self noteHierarchyChanged];
}

- (OPFaultingArray *)children
{
//	NSLog(@"Requesting children of %@", self);
	return children;
}

- (void)insertObject:(GIHierarchyNode *)node inChildrenAtIndex:(NSUInteger)index
{
	[self willChangeValueForKey:@"children"];
	[children insertObject:node atIndex:index];
	[self didChangeValueForKey:@"children"];
	
	[self noteHierarchyChanged];
}

- (void)removeObjectFromChildrenAtIndex:(NSUInteger)index
{
	[children removeObjectAtIndex:index];		
	[self noteHierarchyChanged];
}

- (BOOL)isDeletable
{
	BOOL result = YES;
	for (id child in self.children)
	{
		if (![child isDeletable])
		{
			result = NO;
			break;
		}
	}
	return result;
}

- (void) willDelete
{
	id child;
	while (child = children.lastObject) {
		[child delete];
	}

	[[self.parentNode mutableArrayValueForKey: @"children"] removeObjectIdenticalTo: self];
}

@end

#import "GIMessageGroup.h"

@implementation GIHierarchyNode (MessageGroupHierarchy)

static id rootNode = nil;

+ (id) messageGroupHierarchyRootNode 
{
	OPPersistentObjectContext *context = [OPPersistentObjectContext defaultContext];
	
	if (!rootNode) {
		rootNode = [[context rootObjectForKey:@"MessageGroupHierarchyRootNode"] retain];
		if (!rootNode) {
			[self setMessageGroupHierarchyRootNode: [[[self alloc] init] autorelease]];
		}
	}
	
	return rootNode;
}

+ (void) setMessageGroupHierarchyRootNode: (GIHierarchyNode*) aNode 
{	
	[self willChangeValueForKey: @"MessageGroupHierarchyRootNode"];
	[rootNode autorelease]; rootNode = [aNode retain];
	OPPersistentObjectContext* context = [OPPersistentObjectContext defaultContext];
	[context setRootObject: aNode forKey:@"MessageGroupHierarchyRootNode"];
	[self didChangeValueForKey: @"MessageGroupHierarchyRootNode"];
}

/*" Returns a new message group with name aName at the hierarchy node aNode on position anIndex. If aName is nil, the default name for new groups is being used. If aNode is nil, the group is being put on the root node at last position (anIndex is ignored in this case). "*/ 
+ (id)newWithName:(NSString *)aName atHierarchyNode:(GIHierarchyNode *)aNode atIndex:(int)anIndex
{
    if (!aName) 
	{
        aName = NSLocalizedString(@"New Group", @"Default name for new group");
    }
    
    if (!aNode) 
	{
        aNode = [GIHierarchyNode messageGroupHierarchyRootNode];
    }
	if (anIndex == NSNotFound) anIndex = [[aNode children] count];
	
    // creating new group and setting name:
    GIHierarchyNode *result = [[[self alloc] init] autorelease];
	result.name = aName;
	
    // placing new group in hierarchy:
    NSParameterAssert((anIndex >= 0) && (anIndex <= [[aNode children] count]));
    
	NSMutableArray *children = [aNode mutableArrayValueForKey:@"children"];
	
    if (anIndex >= [children count]) 
	{
        [children addObject:result];
    } 
	else 
	{
        [children insertObject:result atIndex:anIndex];
    }
	
	NSAssert([[aNode children] objectAtIndex:anIndex] == result, @"Hierarchy object not inserted.");
	NSAssert([aNode hasUnsavedChanges], @"parent hierarchy node not dirty.");
    
	return result;
}


- (GIHierarchyNode*) parentNode
/*" Inefficient, reverse lookup! Returns nil for the root node. "*/
{
	GIHierarchyNode* result = [[self class] findHierarchyNode: self 
									startingWithHierarchyNode: [[self class] messageGroupHierarchyRootNode]];
	return result;
}

/*" Returns the hierarchy node in which entry is contained. Starts the search at the hierarchy node aHierarchy. Returns nil if entry couldn't be found in the hierarchy. "*/
+ (GIHierarchyNode *)findHierarchyNode:(id)searchedNode startingWithHierarchyNode:(GIHierarchyNode *)startNode
{
    GIHierarchyNode* result = nil;
    
    if ([startNode.children containsObject:searchedNode]) 
	{
        return startNode;
    }
    
	for (GIHierarchyNode *node in startNode.children)
	{
		result = [self findHierarchyNode:searchedNode startingWithHierarchyNode:node];
		if (result) break;
    }
	
    return result;
}

- (int)unreadMessageCount
{
	return 0;
}

@end