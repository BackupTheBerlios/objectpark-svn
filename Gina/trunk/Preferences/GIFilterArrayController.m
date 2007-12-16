//
//  GIFilterArrayController.m
//  Gina
//
//  Created by Axel Katerbau on 14.12.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import "GIFilterArrayController.h"


@implementation GIFilterArrayController

- (id)newObject
{
	id result = [super newObject];
//	[result setObject:[NSPredicate predicateWithFormat:@"name CONTAINS \"Dirky\""] forKey:@"predicate"];
	return result;
}

- (IBAction)clone:(id)sender
{
	NSMutableArray *newObjects = [NSMutableArray array];
	
	for (id object in [self selectedObjects])
	{
		NSString *name = [[object valueForKey:@"name"] stringByAppendingString:NSLocalizedString(@" copy", @"postfix for cloned filter entries")];
		id clone = [[object mutableCopy] autorelease];
		[clone setValue:name forKey:@"name"];
		
		[newObjects addObject:clone];
	}
	
	if ([newObjects count])
	{
		[self insertObjects:newObjects atArrangedObjectIndexes:[self selectionIndexes]];
		//[self performSelector:@selector(addObjects:) withObject:newObjects afterDelay:0.0];
	}
}

@end
