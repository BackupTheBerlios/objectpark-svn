//
//  GIApplication.h
//  Gina
//
//  Created by Axel Katerbau on 10.12.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class GIMainWindow;

#define GIApp ((GIApplication *)NSApp)

@interface GIApplication : NSApplication 
{
	IBOutlet NSWindow *defaultEmailAppDialog;
	NSTimer* importTimer;
}

- (GIMainWindow*) mainWindow;
- (NSString *)documentPath;

- (BOOL)isDefaultMailApplication;
- (void)askForBecomingDefaultMailApplication;

- (NSOperationQueue *)operationQueue;

// Actions:
- (IBAction)makeDefaultApp:(id)sender;
- (IBAction)openFile:(id)sender;

- (void)runConsistencyChecks:(id)sender;

@end

extern NSString *GISuspendThreadViewUpdatesNotification;
extern NSString *GIResumeThreadViewUpdatesNotification;

@interface GIApplication (SendingAndReceiving)

- (IBAction)sendAndReceiveInAllAccounts:(id)sender;

@end