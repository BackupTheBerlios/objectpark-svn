//
//  ProfilePrefs.h
//  Gina
//
//  Created by Axel Katerbau on 08.03.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <OPPreferences/OPPreferences.h>

@interface GIProfilePrefs : OPPreferencePane 
{
    IBOutlet NSTableView *profileTableView;
	IBOutlet NSArrayController *profilesController;
	IBOutlet NSArrayController *accountsController;
}

- (IBAction)makeDefaultProfile:(id)sender;

- (BOOL)hasGPGAccess;

@end
