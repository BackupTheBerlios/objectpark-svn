//
//  ProfilePrefs.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 08.03.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OPPreferences/OPPreferences.h>

@interface ProfilePrefs : OPPreferencePane 
{
    IBOutlet NSTableView *profileTableView;
}

- (IBAction)setSendAccount:(id)sender;

@end
