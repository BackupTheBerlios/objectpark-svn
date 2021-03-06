//
//  GIApplication.h
//  Gina
//
//  Created by Axel Katerbau on 10.12.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OPPersistentObjectContext.h"
@class GIMainWindow;

#define GIApp ((GIApplication*) NSApp)

@interface GIApplication : NSApplication 
{
	IBOutlet NSWindow* defaultEmailAppDialog;
	IBOutlet NSWindow* groupInspector;
	NSTimer* importTimer;
}

- (OPPersistentObjectContext*) objectContext;

- (IBAction) restoreConfig: (id) sender;
- (IBAction) backupConfig: (id) sender;
- (IBAction) emptyTrash: (id) sender;

- (GIMainWindow*) mainWindow;

- (BOOL)isDefaultMailApplication;
- (void)askForBecomingDefaultMailApplication;

- (NSOperationQueue *)operationQueue;

// Actions:
- (IBAction) makeDefaultApp: (id) sender;
- (IBAction) openFile: (id) sender;
- (IBAction) toggleGroupInspector: (id) sender;

- (void)runConsistencyChecks:(id)sender;

@end

@interface GIApplication (SendingAndReceiving)

- (IBAction)sendAndReceiveInAllAccounts:(id)sender;

@end