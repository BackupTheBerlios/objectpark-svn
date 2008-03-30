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
#import "GIPOPOperation.h"
#import "GIProfile.h"
#import "GISMTPOperation.h"
#import "GIAccount.h"

NSString *GISuspendThreadViewUpdatesNotification = @"GISuspendThreadViewUpdatesNotification";
NSString *GIResumeThreadViewUpdatesNotification = @"GIResumeThreadViewUpdatesNotification";

@implementation GIApplication

- (void)resetMessageStatusSending
{
	// Set status of all messages with OPSendStatusSending back to OPSendStatusQueuedReady:
	NSArray *allProfiles = [[OPPersistentObjectContext defaultContext].allObjectsByClass objectForKey:@"GIProfile"];
	
	for (GIProfile *profile in allProfiles)
    {
		for (GIMessage *message in profile.messagesToSend)
        {
			if (message.sendStatus == OPSendStatusSending) 
            {
				message.sendStatus = OPSendStatusQueuedReady;
			}
		}            
	}
}

- (void)awakeFromNib
{
	//NSLog(@"awakeFromNib");
	// Will be called multiple times, so guard against that:
	if (! [OPPersistentObjectContext defaultContext]) {
		// Setting up persistence:
		NSString *databasePath = [[self applicationSupportPath] stringByAppendingPathComponent:@"Gina.btrees"];
		OPPersistentObjectContext *context = [[[OPPersistentObjectContext alloc] init] autorelease];
		[context setDatabaseFromPath:databasePath];
		[OPPersistentObjectContext setDefaultContext:context];
		
		[GIMessageGroup ensureDefaultGroups];
		[self resetMessageStatusSending];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(smtpOperationDidEnd:) name:GISMTPOperationDidEndNotification object:nil];
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

- (void) importFromImportFolder: (NSNotification*) notification
{
	unsigned importCount = 0;
	NSString *importPath = [[NSApp applicationSupportPath] stringByAppendingPathComponent:@"TransferData to import"];
	OPPersistentObjectContext* context = [OPPersistentObjectContext defaultContext];

	NSDirectoryEnumerator* e = [[NSFileManager defaultManager] enumeratorAtPath: importPath];
	NSMutableArray* filePaths = [NSMutableArray array];
	NSString* filename;
	while (importCount < 10 && (filename = [e nextObject])) {
		if ([filename hasSuffix: @".gml"]) {
			NSDictionary* attrs = [e fileAttributes];
			if ([attrs objectForKey: NSFileType] == NSFileTypeRegular) {
				NSString* filePath = [importPath stringByAppendingPathComponent: filename];
				NSLog(@"Found %@ to import.", filename);
				
				[filePaths addObject: filePath];
				
//				NSData* transferData = [[NSData alloc] initWithContentsOfFile: filePath];
//				OPInternetMessage* inetMessage = [[OPInternetMessage alloc] initWithTransferData: transferData];
//				[transferData release];
//				GIMessage* message = [[GIMessage alloc] initWithInternetMessage: inetMessage];
//				[inetMessage release];
//				[context addMessageByApplingFilters: message];
//				[message release];
				importCount += 1;
//				[[NSFileManager defaultManager] removeFileAtPath: filePath handler: nil];
			}
		}
	}
	
	NSArray* importedMessages = [context importGmlFiles: filePaths moveOnSuccess: YES];

	if (filename && importCount) {
		// There are more messages in the folder to import.
		// Call self to import the rest.
		[self performSelector: _cmd withObject: notification afterDelay: 0.01];
	}
	
	[context saveChanges];
}

- (void) finishLaunching 
{
	registerDefaultDefaults();
	[super finishLaunching];
	
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(importFromImportFolder:) name: GIPOPOperationDidStartNotification object: nil];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(importFromImportFolder:) name: GIPOPOperationDidEndNotification object: nil];
	
	[self ensureMainWindowIsPresent];
//	[self findMissingMessageIds:self];
	[self importFromImportFolder: nil];
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

- (IBAction)sendMessagesDueInNearFuture:(id)sender
{
	NSTimeInterval dueInterval = [[NSUserDefaults standardUserDefaults] integerForKey:SoonRipeMessageMinutes] * 60.0;

	for (GIAccount *account in [[OPPersistentObjectContext defaultContext] allObjectsOfClass:[GIAccount class]])
	{
		[account sendMessagesRipeForSendingAtTimeIntervalSinceNow:dueInterval];
	}
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    NSApplicationTerminateReply result = NSTerminateNow;
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SoonRipeMessagesShouldBeSent])
	{
		NSTimeInterval dueInterval = (NSTimeInterval)[[NSUserDefaults standardUserDefaults] integerForKey:SoonRipeMessageMinutes] * 60.0;
		
		if ([GIAccount anyMessagesRipeForSendingAtTimeIntervalSinceNow:dueInterval])
		{
			[self sendMessagesDueInNearFuture:self];
			sleep(1); // let the jobs begin
			/*
			 NSAlert *alert = [[NSAlert alloc] init];
			 //[alert setTitle:NSLocalizedString(@"Unsent 'due soon' Messages", @"quit dialog due soon messages")];
			 [alert setMessageText:NSLocalizedString(@"There are messages that are due for sending soon which will be send now. Quit canceled.", @"quit dialog due soon messages")];
			 [alert addButtonWithTitle:NSLocalizedString(@"Close", @"quit dialog due soon messages")];
			 [alert runModal];
			 [alert release];
			 return NSTerminateCancel;
			 */
		}
	}
	
    // check open windows
    // if an edit window is open with an edited message ask what to do with the open message
    NSWindow *window;
    NSArray *windows = [NSApp windows];
    NSEnumerator *enumerator = [windows objectEnumerator];
    while (window = [enumerator nextObject])
    {
        if ([[window delegate] respondsToSelector:@selector(windowShouldClose:)])
        {
            if (! [[window delegate] windowShouldClose:self])
            {
                return NSTerminateCancel;
            }
        }
    }
	
//	isTerminating = YES;
	
	NSOperationQueue *queue = [self operationQueue];
	if ([queue operations].count)
	{
		[[self operationQueue] cancelAllOperations];
		[[self operationQueue] waitUntilAllOperationsAreFinished];
		//        result = NSTerminateLater;
	}
    
    return result;
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
	
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	
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
	if (mboxPaths.count) {
		NSArray* importGroups = [context importMboxFiles: mboxPaths moveOnSuccess: NO];
		
		[[defaultEmailAppWindow.windowController messageGroupsController] setSelectedObjects: importGroups];
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:GIResumeThreadViewUpdatesNotification object:self];
}


- (IBAction)openFile:(id)sender
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
    
    if (result == NSOKButton) 
	{
        [[NSUserDefaults standardUserDefaults] setObject:[oPanel directory] forKey:ImportPanelLastDirectory];
        
		[self application: self openFiles: [oPanel filenames]];
	}    
}

- (void) runConsistencyChecks: (id) sender
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

- (NSOperationQueue *)operationQueue
{
	static NSOperationQueue *queue = nil;
	
	if (!queue)
	{
		queue = [[NSOperationQueue alloc] init];
		[queue setMaxConcurrentOperationCount:NSOperationQueueDefaultMaxConcurrentOperationCount];
	}
	
	return queue;
}

@end
	
#import "GIAccount.h"

@implementation GIApplication (SendingAndReceiving)

- (IBAction)sendAndReceiveInAllAccounts:(id)sender
/*" Creates send jobs for accounts with messages that qualify for sending. That are messages that are not blocked (e.g. because they are in the editor) and having flag set (to select send now and queued messages). Creates receive jobs for all accounts."*/
{
	
	NSArray *allAccounts = [[OPPersistentObjectContext defaultContext].allObjectsByClass objectForKey:@"GIAccount"];
	
	[allAccounts makeObjectsPerformSelector:@selector(send)];
	[allAccounts makeObjectsPerformSelector:@selector(receive)];
	[GIAccount resetAccountRetrieveAndSendTimers];
}

- (void)smtpOperationDidEnd:(NSNotification *)aNotification
{
	// Process all messages sent successfully:	
	NSArray *messages = [aNotification.userInfo objectForKey:@"messages"];
	NSAssert(messages != nil, @"userInfo does not contain 'messages'"); // RAISES!
	
	NSArray *sentMessages = [aNotification.userInfo objectForKey:@"sentMessages"];
	NSAssert(sentMessages != nil, @"result does not contain 'sentMessages'");
	
	for (GIMessage *sentMessage in sentMessages)
    {
        // remove from profile:
		GIProfile *sendProfile = [GIProfile sendProfileForMessage:sentMessage];
		[[sendProfile mutableArrayValueForKey:@"messagesToSend"] removeObject:sentMessage];
		
        // remove sent status:
		sentMessage.sendStatus = OPSendStatusNone;
		
		// disconnect thread from queued group:
		[[sentMessage.thread mutableArrayValueForKey:@"messageGroups"] removeObject:[GIMessageGroup queuedMessageGroup]];

		// Disconnect message from its thread:
		[[sentMessage.thread mutableArrayValueForKey:@"messages"] removeObject:sentMessage];
		
		// Re-Insert message wherever it belongs:
		[[OPPersistentObjectContext defaultContext] addMessageByApplingFilters:sentMessage];
	}
    
	NSMutableArray *nonSentMessages = [messages mutableCopy];
	[nonSentMessages removeObjectsInArray:sentMessages];

	for (GIMessage *nonSentMessage in nonSentMessages)
	{
		if (nonSentMessage.sendStatus == OPSendStatusSending) 
		{
			nonSentMessage.sendStatus = OPSendStatusQueuedReady;
		}
	}
	
    [[OPPersistentObjectContext defaultContext] saveChanges];
}

@end
