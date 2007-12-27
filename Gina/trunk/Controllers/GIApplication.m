//
//  GIApplication.m
//  Gina
//
//  Created by Axel Katerbau on 10.12.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import "GIApplication.h"
#import "GIUserDefaultsKeys.h"
#import "GIMainWindowController.h"
#import "GIMessage.h"
#import "OPPersistence.h"
#import "NSApplication+OPExtensions.h"

@implementation GIApplication

- (void)awakeFromNib
{
	NSString *path = [[self applicationSupportPath] stringByAppendingPathComponent:@"Gina.btrees"];
    	
	OPPersistentObjectContext *context = [[[OPPersistentObjectContext alloc] init] autorelease];
	[OPPersistentObjectContext setDefaultContext:context];
	[context setDatabaseFromPath:path];
}

- (BOOL)isDefaultMailApplication
{
	NSString *defaultMailAppBundleIdentifier = (NSString *)LSCopyDefaultHandlerForURLScheme((CFStringRef)@"mailto");
	NSString *bundleIdentifier = [[[NSBundle mainBundle] bundleIdentifier] lowercaseString];
	[defaultMailAppBundleIdentifier autorelease];
	
	return [bundleIdentifier isEqualToString:defaultMailAppBundleIdentifier];
}

- (void)askForBecomingDefaultMailApplication
{
	BOOL shouldAsk = [[NSUserDefaults standardUserDefaults] boolForKey:AskAgainToBecomeDefaultMailApplication];
	
	if (shouldAsk)
	{		
		if (![self isDefaultMailApplication])
		{
			if (!defaultEmailAppWindow)
			{
				[NSBundle loadNibNamed:@"DefaultEmailApp" owner:self];
			}
			
			[defaultEmailAppWindow center];
			[defaultEmailAppWindow makeKeyAndOrderFront:self];
		}		
	}
}

- (void)finishLaunching 
{
	registerDefaultDefaults();
	[super finishLaunching];
	[self askForBecomingDefaultMailApplication];
}

- (IBAction)makeDefaultApp:(id)sender
{
	LSSetDefaultHandlerForURLScheme((CFStringRef)@"mailto", (CFStringRef)[[[NSBundle mainBundle] bundleIdentifier] lowercaseString]);
	[defaultEmailAppWindow close];
}

- (void)ensureMainWindowIsPresent
{
	// ensure a main window:
	for (NSWindow *window in [self windows])
	{
		if ([[window windowController] isKindOfClass:[GIMainWindowController class]])
		{
			return;
		}
	}
	
	[[GIMainWindowController alloc] init];
}

- (void)applicationDidBecomeActive:(NSNotification *)aNotification
{
	[self ensureMainWindowIsPresent];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
//	[self saveOpenWindowsFromThisSession];
	
	[[self windows] makeObjectsPerformSelector:@selector(performClose:) withObject:self];
		
	[GIMessage repairEarliestSendTimes];
	
//	[[GIJunkFilter sharedInstance] writeJunkFilterDefintion];
		
	[[OPPersistentObjectContext defaultContext] saveChanges];
	[[OPPersistentObjectContext defaultContext] close];
}

@end
