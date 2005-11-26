//
//  AccountPrefs.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 09.03.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <OPPreferences/OPPreferences.h>

@interface AccountPrefs : OPPreferencePane 
{
	IBOutlet NSTableView* accountTableView;
}

- (IBAction) removeAccount: (id) sender;
- (IBAction) addAccount: (id) sender;

@end
