//
//  ProfilePrefs.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 08.03.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "ProfilePrefs.h"
#import "G3Profile.h"
#import "G3Account.h"

@implementation ProfilePrefs

- (void)didSelect 
{    
    [self willChangeValueForKey:@"accounts"];
    [self didChangeValueForKey:@"accounts"];
}

- (NSArray *)profiles
{
    return [G3Profile profiles];
}

- (void)setProfiles:(NSArray *)profiles;
{
    [G3Profile setProfiles:profiles];
}

- (NSArray *)accounts
{
/*    G3Account *noneAccount;
    
    noneAccount = [[[G3Account alloc] init] autorelease];
    [noneAccount setName:NSLocalizedString(@"No Account", @"No Account selected in profile")];
    
    return [[G3Account accounts] arrayByAddingObject:noneAccount];
    */
    return [G3Account accounts];
}

- (IBAction)setSendAccount:(id)sender
{
    G3Profile *selectedProfile = [[profileTableView dataSource] itemAtRow:[profileTableView selectedRow]];
    
    [selectedProfile setSendAccount:[sender objectValue]];
}

@end
