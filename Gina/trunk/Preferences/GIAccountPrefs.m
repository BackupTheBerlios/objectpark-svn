//
//  AccountPrefs.m
//  Gina
//
//  Created by Axel Katerbau on 09.03.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "GIAccountPrefs.h"
#import "GIAccount.h"
#import "OPPersistence.h"

@implementation GIAccountPrefs

- (OPPersistentObjectContext*) context
{
	return [OPPersistentObjectContext defaultContext];
}

- (NSArray *)accountSortDescriptors
{
	static NSArray *accountSortDescriptors = nil;
	
	if (!accountSortDescriptors)
	{
		accountSortDescriptors = [[NSArray alloc] initWithObjects:[[[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES] autorelease], nil];
	}
	
	return accountSortDescriptors;
}

@end
