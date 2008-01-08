//
//  GIGeneralPrefs.h
//  Gina
//
//  Created by Axel Katerbau on 16.04.06.
//  Copyright 2006 Objectpark Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OPPreferences/OPPreferences.h>

@interface GIGeneralPrefs : OPPreferencePane 
{
}

- (IBAction)askForBecomingDefaultMailApplication:(id)sender;

@end
