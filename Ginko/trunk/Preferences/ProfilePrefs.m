//
//  ProfilePrefs.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 08.03.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "ProfilePrefs.h"
#import "GIProfile.h"
#import "GIAccount.h"
#import "OPPersistentObject+Extensions.h"

@implementation ProfilePrefs

- (void)didSelect 
{    
    [self willChangeValueForKey:@"accounts"];
    [self didChangeValueForKey:@"accounts"];
}

- (NSArray *)profiles
{
    return [GIProfile allObjects];
}

- (void)setProfiles:(id)accounts
{
	// NOP, only to keep controller happy
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
	[profileTableView selectRow:MIN(selectedRow, [oldList count]-2) byExtendingSelection:NO];
}

- (IBAction)addProfile:(id)sender
{
	OPPersistentObjectContext *context = [OPPersistentObjectContext defaultContext];
	[self willChangeValueForKey:@"profiles"];
	GIProfile *newProfile = [[[GIProfile alloc] init] autorelease];
	[newProfile insertIntoContext:context];
	[context saveChanges];
	[self didChangeValueForKey:@"profiles"];
	[profileTableView selectRow:[[self profiles] indexOfObject:newProfile] byExtendingSelection:NO];
}

- (NSArray *)accounts
{
    return [GIAccount allObjects];
}

- (IBAction)setSendAccount:(id)sender
{
    //GIProfile *selectedProfile = [[profileTableView dataSource] itemAtRow:[profileTableView selectedRow]];
    GIProfile *selectedProfile = [[GIProfile allObjects] objectAtIndex:[profileTableView selectedRow]];
    
    [selectedProfile setValue:[sender objectValue] forKey:@"sendAccount"];
}

- (IBAction)makeDefaultProfile:(id)sender
{
    GIProfile *selectedProfile = [[GIProfile allObjects] objectAtIndex:[profileTableView selectedRow]];
	[selectedProfile makeDefaultProfile];
	[profileTableView reloadData];
}

@end
