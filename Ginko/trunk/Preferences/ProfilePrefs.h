//
//  ProfilePrefs.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 08.03.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <OPPreferences/OPPreferences.h>

@interface ProfilePrefs : OPPreferencePane 
{
    IBOutlet NSTableView* profileTableView;
}

- (IBAction) setSendAccount: (id) sender;
- (IBAction) removeProfile: (id) sender;
- (IBAction) addProfile: (id) sender;

@end
