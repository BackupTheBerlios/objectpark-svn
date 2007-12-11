//
//  GIGeneralPrefs.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 16.04.06.
//  Copyright 2006 Objectpark Group. All rights reserved.
//

#import "GIGeneralPrefs.h"
#import "GIApplication.h"

@implementation GIGeneralPrefs

- (BOOL)isDefaultMailApplication
{
	return [GIApp isDefaultMailApplication];
}

- (IBAction)askForBecomingDefaultMailApplication:(id)sender
{
	[GIApp askForBecomingDefaultMailApplication];
}

@end
