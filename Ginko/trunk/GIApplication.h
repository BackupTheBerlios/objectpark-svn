//
//  GIApplication.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on Mon Jul 19 2004.
//  Copyright (c) 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <AddressBook/AddressBook.h>
#import "OPPersistence.h"

@class GISearchController;

#define GIApp ((GIApplication *)NSApp)

@interface GIApplication : NSApplication 
{
    IBOutlet GISearchController *searchController;

    BOOL isTerminating;
}

- (NSWindow *)groupsWindow;
- (NSString *)databasePath;

/*" Actions "*/
- (IBAction)saveAction: (id) sender;
- (IBAction)showActivityPanel: (id) sender;
- (IBAction)toggleAutomaticActivityPanel: (id) sender;
- (IBAction)startFulltextIndexingJobIfNeeded:(id)sender;

@end

