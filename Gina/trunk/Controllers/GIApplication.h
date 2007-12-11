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
	IBOutlet NSWindow *defaultEmailAppWindow;
}

- (BOOL)isDefaultMailApplication;
- (void)askForBecomingDefaultMailApplication;

- (IBAction)makeDefaultApp:(id)sender;

@end
