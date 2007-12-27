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

- (void)didSelect 
{    
    [self willChangeValueForKey:@"accounts"];
    [self didChangeValueForKey:@"accounts"];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(profileDidChange:) name:GIProfileDidChangNotification object:nil];
}

- (NSSet *)profiles
{
	NSSet *result = [[OPPersistentObjectContext defaultContext] allObjectsOfClass:[GIProfile class]];
    return result;
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

- (IBAction)removeProfile:(id)sender
{	
	int selectedRow = [profileTableView selectedRow];
	NSArray *oldList = [self profiles];
	GIProfile *selectedProfile = [oldList objectAtIndex:[profileTableView selectedRow]];
	OPPersistentObjectContext *context = [selectedProfile context];
	[self willChangeValueForKey: @"profiles"];
	[selectedProfile delete];
	[context saveChanges];
	[self didChangeValueForKey:@"profiles"];
	[profileTableView reloadData];
	[profileTableView selectRow:MIN(selectedRow, [oldList count]-2) byExtendingSelection:NO];
}

- (IBAction)addProfile:(id)sender
{
	OPPersistentObjectContext *context = [OPPersistentObjectContext defaultContext];
	[self willChangeValueForKey:@"profiles"];
	GIProfile *newProfile = [[[GIProfile alloc] init] autorelease];
	[context insertObject:newProfile];
	[context saveChanges];
	[self didChangeValueForKey:@"profiles"];
	[profileTableView reloadData];
	[profilesController setSelectedObjects:[NSArray arrayWithObject:newProfile]];
}

- (NSSet *)accounts
{
	NSSet *result = [[OPPersistentObjectContext defaultContext] allObjectsOfClass:[GIAccount class]];
    return result;
}

/*
- (IBAction)setSendAccount:(id)sender
{
    //GIProfile *selectedProfile = [[profileTableView dataSource] itemAtRow:[profileTableView selectedRow]];
    GIProfile *selectedProfile = [[GIProfile allObjects] objectAtIndex:[profileTableView selectedRow]];
    
    [selectedProfile setValue:[sender objectValue] forKey:@"sendAccount"];
}
*/

- (IBAction)makeDefaultProfile:(id)sender
{
    GIProfile *selectedProfile = [[profilesController selectedObjects] lastObject];
	[selectedProfile makeDefaultProfile];
	[profilesController rearrangeObjects];
}

- (void)profileDidChange:(NSNotification *)aNotification
{
	if ([[[aNotification userInfo] objectForKey:@"key"] isEqualToString:@"name"])
	{
		[self willChangeValueForKey:@"accounts"];
		[self didChangeValueForKey:@"accounts"];
	}
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
