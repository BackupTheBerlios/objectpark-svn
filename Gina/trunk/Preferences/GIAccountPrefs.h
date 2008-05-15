//
//  AccountPrefs.h
//  Gina
//
//  Created by Axel Katerbau on 09.03.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <OPPreferences/OPPreferences.h>

@class OPPersistentObjectContext;

@interface GIAccountPrefs : OPPreferencePane 
{
	IBOutlet NSTableView *accountTableView;
    IBOutlet NSArrayController *accountsController;
	
	NSTimer *updateTimer;
}

@property (readonly) OPPersistentObjectContext *context;
@property (readwrite, retain) NSTimer *updateTimer;

- (IBAction)sendAndReceive:(id)sender;

@end
