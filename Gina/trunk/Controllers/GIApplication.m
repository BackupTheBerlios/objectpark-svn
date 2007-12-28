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
	// Will be called multiple times, so guard against that:
	if (! [OPPersistentObjectContext defaultContext]) {
		// Setting up persistence:
		NSString *databasePath = [[self applicationSupportPath] stringByAppendingPathComponent:@"Gina.btrees"];
		OPPersistentObjectContext *context = [[[OPPersistentObjectContext alloc] init] autorelease];
		[context setDatabaseFromPath:databasePath];
		[OPPersistentObjectContext setDefaultContext:context];
	}
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
		if ([[window delegate] isKindOfClass:[GIMainWindowController class]])
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
	
#warning the following line will make Ginko beep at the end
//	[[self windows] makeObjectsPerformSelector:@selector(performClose:) withObject:self];
		
	[GIMessage repairEarliestSendTimes];
	
//	[[GIJunkFilter sharedInstance] writeJunkFilterDefintion];
		
	// shutting down persistence:
	[[OPPersistentObjectContext defaultContext] saveChanges];
	[[OPPersistentObjectContext defaultContext] close];
}

@end
