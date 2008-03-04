//
//  GIApplication.h
//  Gina
//
//  Created by Axel Katerbau on 10.12.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define GIApp ((GIApplication *)NSApp)

@interface GIApplication : NSApplication 
{
	IBOutlet NSWindow* defaultEmailAppWindow;
}


- (BOOL) isDefaultMailApplication;
- (void) askForBecomingDefaultMailApplication;

// Actions:

- (IBAction) makeDefaultApp: (id) sender;
- (IBAction) openFile: (id) sender;

- (void) runConsistencyChecks: (id) sender;


@end

extern NSString *GISuspendThreadViewUpdatesNotification;
extern NSString *GIResumeThreadViewUpdatesNotification;