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
#import "GIMessageGroup.h"
#import "GIMessageBase.h"
#import "OPPersistence.h"
#import "NSApplication+OPExtensions.h"
#import <Foundation/NSDebug.h>

NSString *GISuspendThreadViewUpdatesNotification = @"GISuspendThreadViewUpdatesNotification";
NSString *GIResumeThreadViewUpdatesNotification = @"GIResumeThreadViewUpdatesNotification";

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
		
		[GIMessageGroup ensureDefaultGroups];
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
	static BOOL firstTime = YES;
	
	[self ensureMainWindowIsPresent];
	
	if (firstTime)
	{
		[self askForBecomingDefaultMailApplication];
		firstTime = NO;
	}
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
//	[self saveOpenWindowsFromThisSession];
			
	[GIMessage repairEarliestSendTimes];
	
//	[[GIJunkFilter sharedInstance] writeJunkFilterDefintion];
		
	// shutting down persistence:
	[[OPPersistentObjectContext defaultContext] saveChanges];
	[[OPPersistentObjectContext defaultContext] close];
}

- (NSArray *)filePathsSortedByCreationDate:(NSArray *)someFilePaths
{
#warning Implement filePathsSortedByCreationDate for better mbox restore
    return someFilePaths;
}

- (IBAction) importMboxFile: (id) sender
/*" Imports one or more mbox files. Recognizes plain mbox files with extension .mboxfile and .mbx and NeXT/Apple style bundles with the .mbox extension. "*/
{
    int result;
    NSArray *fileTypes = [NSArray arrayWithObjects: @"mboxfile", @"mbox", @"mbx", nil];
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
    NSString *directory = [[NSUserDefaults standardUserDefaults] objectForKey:ImportPanelLastDirectory];
    
    if (!directory) directory = NSHomeDirectory();
    
    [oPanel setAllowsMultipleSelection:YES];
    [oPanel setAllowsOtherFileTypes:YES];
    [oPanel setPrompt:NSLocalizedString(@"Import", @"Import open panel OK button")];
    [oPanel setTitle:NSLocalizedString(@"Import mbox Files", @"Import open panel title")];
    
    result = [oPanel runModalForDirectory:directory file:nil types:fileTypes];
    
    if (result == NSOKButton) {
        [[NSUserDefaults standardUserDefaults] setObject:[oPanel directory] forKey:ImportPanelLastDirectory];
        
        NSArray *filesToOpen = [self filePathsSortedByCreationDate:[oPanel filenames]];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:GISuspendThreadViewUpdatesNotification object:self];
		[[OPPersistentObjectContext defaultContext] importMboxFiles: filesToOpen moveOnSuccess: NO];
		[[NSNotificationCenter defaultCenter] postNotificationName:GIResumeThreadViewUpdatesNotification object:self];
    }    
}


@end
