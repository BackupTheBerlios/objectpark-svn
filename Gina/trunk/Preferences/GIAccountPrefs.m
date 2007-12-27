//
//  AccountPrefs.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 09.03.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "GIAccountPrefs.h"
#import "GIAccount.h"
#import "OPPersistence.h"

@implementation GIAccountPrefs

- (NSSet *)accounts
{
	NSSet *result = [[OPPersistentObjectContext defaultContext] allObjectsOfClass:[GIAccount class]];
    return result;
}

- (IBAction)removeAccount:(id)sender
{	
	NSArray *selectedObjects = [accountsController selectedObjects];
//	int count = [selectedObjects count];
	GIAccount *selectedAccount = [selectedObjects lastObject];
//	int selectedRow = [accountTableView selectedRow];

	[self willChangeValueForKey:@"accounts"];
	[selectedAccount delete];
	[[selectedAccount context] saveChanges];
	[self didChangeValueForKey:@"accounts"];
    
//	[accountTableView selectRow:MIN(selectedRow, count - 2) byExtendingSelection:NO];
}

- (IBAction)addAccount:(id)sender
{
	OPPersistentObjectContext *context = [OPPersistentObjectContext defaultContext];
	[self willChangeValueForKey:@"accounts"];
	[context insertObject:[[GIAccount alloc] init]];
	[context saveChanges];
	[self didChangeValueForKey:@"accounts"];
}

- (IBAction)rearrangeObjects:(id)sender;
/*" This action triggers the refresh of interface elements that change their value according to the actual change. "*/
{
    [accountsController rearrangeObjects];
}

@end
