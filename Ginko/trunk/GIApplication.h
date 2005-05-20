//
//  GIApplication.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on Mon Jul 19 2004.
//  Copyright (c) 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <AddressBook/AddressBook.h>

#define GIApp ((GIApplication*)NSApp)

@interface GIApplication : NSApplication 
{
}

- (BOOL)isGroupsDrawerMode;
- (NSWindow *)standaloneGroupsWindow;

/*" Actions "*/
- (IBAction)openNewGroupWindow:(id)sender;

//- (IBAction) importTestMBox: (id) sender;
- (IBAction) saveAction: (id) sender;
- (IBAction) importTestMBox: (id) sender;

@end
