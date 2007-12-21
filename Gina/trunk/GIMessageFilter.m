//
//  GIMessageFilter.m
//  Gina
//
//  Created by Axel Katerbau on 21.12.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import "GIMessageFilter.h"


@implementation GIMessageFilter

static NSMutableArray *filters = nil;

+ (NSMutableArray *)filters
{	
	if (!filters)
	{
		filters = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Filters"] mutableCopy];
		if (!filters)
		{
			filters = [[NSMutableArray alloc] init];
		}
	}
	
	return filters;
}

+ (void)setFilters:(NSMutableArray *)someFilters
{
	[filters autorelease];
	filters = [someFilters retain];
	[self saveFilters];
}

+ (void)saveFilters
{
	[[NSUserDefaults standardUserDefaults] setObject:filters forKey:@"Filters"];
}

/*" Returns a (sub)set of the receiver's filters which match for the given message. "*/
+ (NSArray *)filtersMatchingForMessage:(id)message
{
    NSMutableArray *result = [NSMutableArray array];
	    
    for (id filter in [self filters]) 
    {
		NSString *predicateFormat = [filter valueForKey:@"predicateFormat"];
		NSPredicate *predicate = [NSPredicate predicateWithFormat:predicateFormat];
		
        if ([predicate evaluateWithObject:message]) 
        {
            [result addObject:filter];
        }
    }
    
    return result;
}

@end
