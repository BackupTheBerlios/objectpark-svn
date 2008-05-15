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

@synthesize updateTimer;

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

/*" Invoked when the pref panel was selected. Initialization stuff. "*/
- (void)didSelect
{
	self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(periodicUpdate:) userInfo:nil repeats:YES];
}
	
/*" Invoked when the pref panel is about to be quit. "*/
- (void)willUnselect
{
	[self.updateTimer invalidate];
	self.updateTimer = nil;
}

- (void)periodicUpdate:(NSTimer *)aTimer
{
	GIAccount *account = [[accountsController selectedObjects] lastObject];
	[[account sendAndReceiveTimer] willChangeValueForKey:@"minutesUntilFire"];
	[[account sendAndReceiveTimer] didChangeValueForKey:@"minutesUntilFire"];
}

- (IBAction)sendAndReceive:(id)sender
{
	GIAccount *account = [[accountsController selectedObjects] lastObject];
	[account sendAndReceive];
}

@end
