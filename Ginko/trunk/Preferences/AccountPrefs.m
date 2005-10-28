//
//  AccountPrefs.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 09.03.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "AccountPrefs.h"
#import "GIAccount.h"

@implementation AccountPrefs

- (NSArray*) accounts
{
    return [GIAccount accounts];
}


@end
