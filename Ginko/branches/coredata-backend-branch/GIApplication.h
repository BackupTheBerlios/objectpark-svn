//
//  GIApplication.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on Mon Jul 19 2004.
//  Copyright (c) 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <AddressBook/AddressBook.h>

@class GISearchController;

#define GIApp ((GIApplication *)NSApp)

@interface GIApplication : NSApplication 
{
    IBOutlet GISearchController *searchController;
}

- (BOOL)isGroupsDrawerMode;
- (NSWindow *)standaloneGroupsWindow;
- (NSManagedObjectContext*) newManagedObjectContext;

- (NSString *)databasePath;

/*" Actions "*/
- (IBAction)openNewGroupWindow:(id)sender;

- (IBAction)saveAction:(id)sender;
- (IBAction)openSearchWindow:(id)sender;
- (IBAction)showActivityPanel:(id)sender;

@end
