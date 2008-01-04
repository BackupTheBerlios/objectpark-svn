//
//  ProfilePrefs.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 08.03.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "GIProfilePrefs.h"
#import "GIProfile.h"
#import "GIAccount.h"
#import "NSError+Extensions.h"
#import "GIApplication.h"
#import "OPPersistence.h"

@implementation GIProfilePrefs

- (OPPersistentObjectContext*) context
{
	return [OPPersistentObjectContext defaultContext];
}

- (NSArray *)nameSortDescriptors
{
	static NSArray *accountSortDescriptors = nil;
	
	if (!accountSortDescriptors)
	{
		accountSortDescriptors = [[NSArray alloc] initWithObjects:[[[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES] autorelease], nil];
	}
	
	return accountSortDescriptors;
}

- (IBAction)makeDefaultProfile:(id)sender
{
    GIProfile *selectedProfile = [[profilesController selectedObjects] lastObject];
	[selectedProfile makeDefaultProfile];
	[profilesController rearrangeObjects];
}

- (BOOL)hasGPGAccess
{
	return NO;
	
	//return [GIApp hasGPGAccess];
}

@end


//#import <GPGME/GPGME.h>

@implementation GIProfilePrefs (OpenPGP)

- (NSArray *)matchingKeys
{
    GIProfile *selectedProfile = [[profilesController selectedObjects] lastObject];
	return [selectedProfile matchingKeys];
}

- (BOOL)hasMatchingKeys
{
	return [[self matchingKeys] count] > 0;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	[self willChangeValueForKey:@"hasMatchingKeys"];
	[self didChangeValueForKey:@"hasMatchingKeys"];
}

@end
