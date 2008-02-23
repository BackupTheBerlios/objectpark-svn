//
//  GIApplication.m
//  Gina
//
//  Created by Axel Katerbau on 10.12.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import "GIApplication.h"
#import "OPPersistentObjectContext.h";
#import "GIUserDefaultsKeys.h"
#import "GIMainWindowController.h"
#import "GIMessage.h"
#import "GIThread.h"
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
	NSLog(@"awakeFromNib");
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
	
	[[[GIMainWindowController alloc] init] autorelease];
}

- (void)finishLaunching 
{
	registerDefaultDefaults();
	[super finishLaunching];
	
	[self ensureMainWindowIsPresent];
//	[self findMissingMessageIds:self];
}

- (IBAction)makeDefaultApp:(id)sender
{
	LSSetDefaultHandlerForURLScheme((CFStringRef)@"mailto", (CFStringRef)[[[NSBundle mainBundle] bundleIdentifier] lowercaseString]);
	[defaultEmailAppWindow close];
}

- (void)applicationDidBecomeActive:(NSNotification *)aNotification
{
	static BOOL firstTime = YES;
	
	[self ensureMainWindowIsPresent];
	
	if (firstTime) {
		[self askForBecomingDefaultMailApplication];
		firstTime = NO;
	}
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
//	[self saveOpenWindowsFromThisSession];
			
	[GIMessage repairEarliestSendTimes];
	
//	[[GIJunkFilter sharedInstance] writeJunkFilterDefintion];
}

- (void) terminate: (id) sender
{
	// shutting down persistence:
	[[OPPersistentObjectContext defaultContext] saveChanges];
	[[OPPersistentObjectContext defaultContext] close];	
	
	[super terminate: sender];
}

- (NSArray *)filePathsSortedByCreationDate:(NSArray *)someFilePaths
{
#warning Implement filePathsSortedByCreationDate for better mbox restore
    return someFilePaths;
}

- (BOOL) application: (NSApplication*) sender openFile: (NSString*) filename
{
	[self application: sender openFiles: [NSArray arrayWithObject: filename]];
	return YES;
}




- (void) application: (NSApplication*) sender openFiles: (NSArray*) filePaths
{
	filePaths = [self filePathsSortedByCreationDate: filePaths];
	NSArray* mboxPaths = [filePaths pathsMatchingExtensions: [NSArray arrayWithObjects: @"mbox", @"mboxfile", @"mbx", nil]];
	NSArray* gmls = [filePaths pathsMatchingExtensions: [NSArray arrayWithObjects: @"gml", nil]];
	OPPersistentObjectContext* context = [OPPersistentObjectContext defaultContext];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:GISuspendThreadViewUpdatesNotification object:self];	
	if (gmls.count) {
		NSArray* messages = [context importGmlFiles: gmls moveOnSuccess: NO];	
		GIMessage* lastMessage = [messages lastObject];
		[defaultEmailAppWindow.windowController showMessage: lastMessage];
	}
	if (mboxPaths.count)
		[context importMboxFiles: mboxPaths moveOnSuccess: NO];
	[[NSNotificationCenter defaultCenter] postNotificationName:GIResumeThreadViewUpdatesNotification object:self];
}


- (IBAction) openFile: (id) sender
/*" Imports one or more mbox files. Recognizes plain mbox files with extension .mboxfile and .mbx and NeXT/Apple style bundles with the .mbox extension. "*/
{
    int result;
    NSArray* fileTypes = [NSArray arrayWithObjects: @"mboxfile", @"mbox", @"mbx", @"gml", nil];
    NSOpenPanel* oPanel = [NSOpenPanel openPanel];
    NSString *directory = [[NSUserDefaults standardUserDefaults] objectForKey: ImportPanelLastDirectory];
    
    if (!directory) directory = NSHomeDirectory();
    
    [oPanel setAllowsMultipleSelection:YES];
    [oPanel setAllowsOtherFileTypes:YES];
    [oPanel setPrompt:NSLocalizedString(@"Import", @"Import open panel OK button")];
    [oPanel setTitle:NSLocalizedString(@"Import mbox Files", @"Import open panel title")];
    
    result = [oPanel runModalForDirectory:directory file:nil types:fileTypes];
    
    if (result == NSOKButton) {
        [[NSUserDefaults standardUserDefaults] setObject:[oPanel directory] forKey:ImportPanelLastDirectory];
        
		[self application: self openFiles: [oPanel filenames]];
	}    
}

- (void) runConsistentcyChecks: (id) sender
{
	GIMessageGroup* group = [GIMessageGroup defaultMessageGroup];
	NSLog(@"Walking %u threads:", group.threads.count);
	unsigned threadCounter = 0;
	for (GIThread* thread in group.threads) {
		NSLog(@"Walking %@", thread);
		for (GIMessage* message in thread.messages) {
			//NSLog(@"Walking %@", message);
			GIMessage* referenced = message.reference;
			if (referenced) {
				if (referenced.thread != message.thread) {
					NSLog(@"inconsistency detected. Message %@ refers to %@, but they are not in the same thread.", message, referenced);
				}
			}
		}
		threadCounter++;
	}
	NSLog(@"Finished successfully. Walked %u threads.", threadCounter);
}

@end
	
#import "NSCharacterSet+MIME.h"

@implementation GIApplication (MessageLeakingTest)

- (IBAction)findMissingMessageIds:(id)sender
{
	NSString *messageIdsFilePath = [[NSBundle mainBundle] pathForResource:@"Message-Ids" ofType:@"txt"];
	NSAssert(messageIdsFilePath != nil, @"could not find file");
	
	NSString *messageIdsString = [NSString stringWithContentsOfFile:messageIdsFilePath];
	NSAssert(messageIdsString != nil, @"could not read file");
	
	NSArray *messageIds = [messageIdsString componentsSeparatedByCharactersInSet:[NSCharacterSet linebreakCharacterSet]];
	
	OPPersistentObjectContext *context = [OPPersistentObjectContext defaultContext];
	
	for (NSString *messageId in messageIds)
	{
		GIMessage *message = [context messageForMessageId:messageId];
		if (!message)
		{
			NSLog(@"Found missing message with ID: %@", messageId);
		}
	}
}

@end
