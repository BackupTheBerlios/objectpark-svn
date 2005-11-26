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

- (void) didSelect 
{    
    [self willChangeValueForKey: @"accounts"];
    [self didChangeValueForKey: @"accounts"];
}

- (NSArray*) profiles
{
    return [GIProfile allObjects];
}

- (IBAction) removeProfile: (id) sender
{	
	int selectedRow = [profileTableView selectedRow];
	NSArray* oldList = [self profiles];
	GIProfile* selectedProfile = [oldList objectAtIndex: [profileTableView selectedRow]];
	[self willChangeValueForKey: @"profiles"];
	[[selectedProfile context] deleteObject: selectedProfile];
	[[selectedProfile context] saveChanges];
	[self didChangeValueForKey: @"profiles"];
	[profileTableView selectRow: MIN(selectedRow, [oldList count]-2) byExtendingSelection: NO];
}

- (IBAction) addProfile: (id) sender
{
	OPPersistentObjectContext* context = [OPPersistentObjectContext defaultContext];
	[self willChangeValueForKey: @"profiles"];
	GIProfile* newProfile = [[[GIProfile alloc] init] autorelease];
	[newProfile insertIntoContext: context];
	[context saveChanges];
	[self didChangeValueForKey: @"profiles"];
	[profileTableView selectRow: [[self profiles] indexOfObject: newProfile] byExtendingSelection: NO];
}


- (NSArray*) accounts
{
    return [[GIAccount allObjectsEnumerator] allObjects];
}

- (IBAction) setSendAccount: (id) sender
{
    GIProfile* selectedProfile = [[profileTableView dataSource] itemAtRow: [profileTableView selectedRow]];
    
    [selectedProfile setValue: [sender objectValue] forKey: @"sendAccount"];
}

@end
