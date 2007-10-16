//
//  GIMainWindowController.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 12.10.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import "GIMainWindowController.h"

// helper
#import "NSArray+Extensions.h"

// model stuff
#import "GIMessageGroup.h"

@implementation GIMessageGroup (copying)
- (id)copyWithZone:(NSZone *)aZone
{
	return [self retain];
}
@end

@interface GIMessageGroup (MessageGroupHierarchySupport)
- (NSArray *)children;
- (NSNumber *)count;
@end

@implementation GIMessageGroup (MessageGroupHierarchySupport)
- (NSArray *)children
{
	return nil;
}

- (NSNumber *)count
{
	return [NSNumber numberWithInt:0];
}

@end

@interface NSArray (MessageGroupHierarchySupport)
- (NSDictionary *)messageGroupHierarchyAsDictionaries;
@end

@implementation NSArray (MessageGroupHierarchySupport)

- (NSDictionary *)messageGroupHierarchyAsDictionaries
{
	NSMutableArray *children = [NSMutableArray array];
	if ([self count] >= 2) 
	{
		NSEnumerator *enumerator = [[self subarrayFromIndex:1] objectEnumerator];
		id object;
		
		while (object = [enumerator nextObject])
		{
			if ([object isKindOfClass:[NSArray class]])
			{
				[children addObject:[object messageGroupHierarchyAsDictionaries]];
			}
			else
			{
				GIMessageGroup *group = [OPPersistentObjectContext objectWithURLString:object resolve:YES];
				NSAssert1([group isKindOfClass:[GIMessageGroup class]], @"Object is not a GIMessageGroup object: %@", object);
				[children addObject:group];
			}
		}
	}
	
	return [NSDictionary dictionaryWithObjectsAndKeys:
		[[self objectAtIndex:0] objectForKey:@"name"], @"name",
		[[self objectAtIndex:0] objectForKey:@"uid"], @"uid",
		[NSNumber numberWithInt:[children count]], @"count",
		children, @"children",
		nil, nil];
}


@end

@implementation GIMainWindowController

- (id)init
{
	self = [self initWithWindowNibName:@"MainWindow"];
	
	[self loadWindow];
	
	return self;
}

- (NSArray *)messageGroupHierarchyRoot
{
	return [[[GIMessageGroup hierarchyRootNode] messageGroupHierarchyAsDictionaries] objectForKey:@"children"];
}

- (NSFont *)messageGroupListFont
{
	return [NSFont systemFontOfSize:12.0];
}

- (float)messageGroupListRowHeight
{
	return 17.0;
}

@end
