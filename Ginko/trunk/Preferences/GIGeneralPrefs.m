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

- (BOOL)isGinkoStandardMailApplication
{
	return [GIApp isGinkoStandardMailApplication];
}

- (IBAction)askForBecomingDefaultMailApplication:(id)sender
{
	[GIApp askForBecomingDefaultMailApplication];
}

@end
