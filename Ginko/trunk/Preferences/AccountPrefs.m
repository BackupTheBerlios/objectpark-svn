//
//  AccountPrefs.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 09.03.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "AccountPrefs.h"
#import "G3Account.h"

@implementation AccountPrefs

- (NSArray *)accounts
{
    return [G3Account accounts];
}

- (void)setAccounts:(NSArray *)someAccounts
{
    [G3Account setAccounts:someAccounts];
}

@end
