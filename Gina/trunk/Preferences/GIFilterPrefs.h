//
//  GIFilterPrefs.h
//  Gina
//
//  Created by Axel Katerbau on 13.12.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OPPreferences/OPPreferences.h>

@interface GIFilterPrefs : OPPreferencePane 
{
	IBOutlet NSArrayController *filterArrayController;
	IBOutlet NSPredicateEditor *predicateEditor;
	
	NSIndexSet *selectedFilterIndexes;
}

- (Class) messageFilterClass;


- (IBAction)delete:(id)sender;

@end
