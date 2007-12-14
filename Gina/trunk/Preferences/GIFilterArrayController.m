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

@end
