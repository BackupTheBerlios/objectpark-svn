//
//  Application.m
//  OPPreferencesTest
//
//  Created by Dirk Theisen on Sat Feb 02 2002.
//  Copyright (c) 2001 Dirk Theisen. All rights reserved.
//
/*
 Permission to use, copy, modify and distribute this software and its documentation
 is hereby granted, provided that both the copyright notice and this permission
 notice appear in all copies of the software, derivative works or modified versions,
 and any portions thereof, and that both notices appear in supporting documentation,
 and that credit is given to Bjoern Bubbat in all documents and publicity
 pertaining to direct or indirect use of this code or its derivatives.

 THIS IS EXPERIMENTAL SOFTWARE AND IT IS KNOWN TO HAVE BUGS, SOME OF WHICH MAY HAVE
 SERIOUS CONSEQUENCES. THE COPYRIGHT HOLDER ALLOWS FREE USE OF THIS SOFTWARE IN ITS
 "AS IS" CONDITION. THE COPYRIGHT HOLDER DISCLAIMS ANY LIABILITY OF ANY KIND FOR ANY
 DAMAGES WHATSOEVER RESULTING DIRECTLY OR INDIRECTLY FROM THE USE OF THIS SOFTWARE
 OR OF ANY DERIVATIVE WORK.

 Further information can be found on the project's web pages
 at http://www.objectpark.org/
 */

#import "NSApplicationOPPreferenceSupport.h"
#import "OPPreferenceController.h"


@implementation NSApplication (OPPreferenceSupport)

- (IBAction) openPreferences: (id) sender 
{
	[OPPreferenceController showPreferencesWindow];
}

- (NSArray*) activePrefPanes 
/*" Returns an array of Preference Pane identifiers (NSStrings), each resembling the name of a tiff, a localizatible string and a name of a nib and file. By implementing this method, the delegate can override the default behaviour which is to load the array returned from a file called ActivePrefPanes.plist from the main bundle. "*/
{
    NSArray*  activePrefPanes = nil;
    id delegate = [self delegate];
    if (self != delegate && [delegate respondsToSelector: @selector(activePrefPanes)]) {
        activePrefPanes = [[self delegate] activePrefPanes];
    }
    if (!activePrefPanes) {
        // Load it from the ActivePrefPanes.plist file:
        activePrefPanes = [[NSString stringWithContentsOfFile: [[NSBundle mainBundle] pathForResource: @"ActivePrefPanes" ofType: @"plist"]] propertyList];
        
        if (!activePrefPanes) {
			
			NSBundle* appBundle = [NSBundle bundleForClass: [self class]];
			
			activePrefPanes = [appBundle objectForInfoDictionaryKey: @"OPActivePrefPanes"];
			
			if (!activePrefPanes) {
				NSLog(@"OPPreferences: Warning - Unable to load 'ActivePrefPanes.plist' resource.");
				return nil;
			}
        }
    }
    return activePrefPanes;
}

@end
