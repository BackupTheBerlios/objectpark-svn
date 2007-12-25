//
//  AccountPrefs.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 09.03.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <OPPreferences/OPPreferences.h>

@interface GIAccountPrefs : OPPreferencePane 
{
	IBOutlet NSTableView *accountTableView;
    IBOutlet NSArrayController *accountsController;
}

- (IBAction)removeAccount:(id)sender;
- (IBAction)addAccount:(id)sender;
- (IBAction)rearrangeObjects:(id)sender;

@end
