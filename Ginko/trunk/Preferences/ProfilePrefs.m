//
//  ProfilePrefs.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 08.03.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "ProfilePrefs.h"
#import "GIProfile.h"
#import "G3Account.h"

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

- (void)setProfiles:(NSArray *)profiles;
{
    [GIProfile setProfiles:profiles];
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
    GIProfile *selectedProfile = [[profileTableView dataSource] itemAtRow:[profileTableView selectedRow]];
    
    [selectedProfile setValue: [sender objectValue] forKey: @"sendAccount"];
}

@end
