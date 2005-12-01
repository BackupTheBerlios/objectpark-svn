//
//  AccountPrefs.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 09.03.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "AccountPrefs.h"
#import "GIAccount.h"
#import "OPPersistentObject+Extensions.h"

@implementation AccountPrefs

- (NSArray *)accounts
{
    return [[GIAccount allObjectsEnumerator] allObjects];
}

- (IBAction)removeAccount:(id)sender
{	
	int selectedRow = [accountTableView selectedRow];
	NSArray *oldList = [self accounts];
	GIAccount *selectedAccount = [oldList objectAtIndex:[accountTableView selectedRow]];
    
	[self willChangeValueForKey:@"accounts"];
	[[selectedAccount context] deleteObject:selectedAccount];
	[[selectedAccount context] saveChanges];
	[self didChangeValueForKey:@"accounts"];
    
	[accountTableView selectRow:MIN(selectedRow, [oldList count] - 2) byExtendingSelection:NO];
}

- (IBAction)addAccount:(id)sender
{
	OPPersistentObjectContext *context = [OPPersistentObjectContext defaultContext];
	[self willChangeValueForKey:@"accounts"];
	GIAccount *newAccount = [[[GIAccount alloc] init] autorelease];
	[newAccount insertIntoContext:context];
	[context saveChanges];
	[self didChangeValueForKey:@"accounts"];
	[accountTableView selectRow:[[self accounts] indexOfObject:newAccount] byExtendingSelection:NO];
}

- (IBAction)rearrangeObjects:(id)sender;
/*" This action triggers the refresh of interface elements that change their value according to the actual change. "*/
{
    [accountsController rearrangeObjects];
}

@end
