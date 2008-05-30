//
//  GIApplication.m
//  Gina
//
//  Created by Axel Katerbau on 10.12.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import "GIApplication.h"
#import "OPPersistentObjectContext.h"
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
#import "GIMessageGroupOutlineViewController.h"
#import "GIMessageFilter.h"

@implementation GIApplication

- (void) resetMessageStatusSending
{
	// Set status of all messages with OPSendStatusSending back to OPSendStatusQueuedReady:
	NSArray *allProfiles = [self.context.allObjectsByClass objectForKey:@"GIProfile"];
	
	for (GIProfile *profile in allProfiles) {
		for (GIMessage *message in profile.messagesToSend) {
			if (message.sendStatus == OPSendStatusSending) {
				message.sendStatus = OPSendStatusQueuedReady;
			}
		}            
	}
}


- (void) ensureSomeWindowIsPresent
{
	// ensure a main window:
	if (! [self.windows count]) {
		if (! self.mainWindow) {
			[[[GIMainWindowController alloc] init] autorelease];
		} else {
			[self.mainWindow makeKeyAndOrderFront: self];
		}
	}
}

- (IBAction) backupConfig: (id) sender
{
	[self.context saveChanges];
	
	NSSet*   profiles = [self.context allObjectsOfClass: [GIProfile class]];
	NSSet*   accounts = [self.context allObjectsOfClass: [GIAccount class]];
	NSArray* filters  = [GIMessageFilter filters];
	
	NSDictionary* config = [NSDictionary dictionaryWithObjectsAndKeys: 
							profiles, @"Profiles", 
							accounts, @"Accounts",
							filters,  @"Filters",
							[GIHierarchyNode messageGroupHierarchyRootNode] , @"GroupHierarchyRoot",
							nil, nil];
	
	NSData* backupData = [NSKeyedArchiver archivedDataWithRootObject: config];
	[[NSUserDefaults standardUserDefaults] setObject: backupData forKey: @"ConfigurationBackup"];
}

- (IBAction) restoreConfig: (id) sender
{
	NSData* backupData = [[NSUserDefaults standardUserDefaults] dataForKey: @"ConfigurationBackup"];
	if (backupData.length) {
		NSAlert* restoreAlert = [NSAlert alertWithMessageText: @"Restore Preferences?" defaultButton: @"Restore" alternateButton: @"Cancel" otherButton: nil informativeTextWithFormat: @"Your Gina preferences are not set, but a backup of the preferences exists. This happens if the Gina database has been deleted or cannot be found. Do you want to restore some preferences from the backup?"];
		int result = [restoreAlert runModal];
		if (result == NSAlertDefaultReturn) {
			
			NSDictionary* config = [NSKeyedUnarchiver unarchiveObjectWithData: backupData];
			/*NSSet* profiles = */[config objectForKey: @"Profiles"]; // will automatically be put into the default context und cached.
			/*NSSet* accounts = */[config objectForKey: @"Accounts"]; // will automatically be put into the default context und cached.
			OPFaultingArray* filters  = [config objectForKey: @"Filters"]; // will automatically be put into the default context und cached.
			[self.context setRootObject: filters forKey: @"Filters"];
			GIHierarchyNode* rootGroup = [config objectForKey: @"GroupHierarchyRoot"];
			[GIHierarchyNode setMessageGroupHierarchyRootNode: rootGroup];
			NSLog(@"Restored Groups: %@", rootGroup.children);
			NSLog(@"Restored %@", config);
		}
		//GIAccount* anyAccount = [accounts anyObject];
		//NSLog(@"Restored %@", accounts);
		[self performSelector: @selector(ensureSomeWindowIsPresent) withObject: nil afterDelay: 0.1]; // otherwise, the alert panel is still in the window list
	}
}

- (void) awakeFromNib
{
	//NSLog(@"awakeFromNib");
	// Will be called multiple times, so guard against that:
	if (! self.context) 
	{
		// Setting up persistence:
		OPPersistentObjectContext *context = [[[OPPersistentObjectContext alloc] init] autorelease];
		[OPPersistentObjectContext setDefaultContext:context];
		NSString *databasePath = [context.documentPath stringByAppendingPathComponent:@"Gina.btrees"];

		[context setDatabaseFromPath:databasePath];
		
		if ([[[self context] allObjectsOfClass:[GIProfile class]] count] == 0) 
		{
			[self restoreConfig:self];
		}
		
		[GIMessageGroup ensureDefaultGroups];
		[self resetMessageStatusSending];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(smtpOperationDidEnd:) name:GISMTPOperationDidEndNotification object:nil];
		
		[GIAccount resetAccountRetrieveAndSendTimers];
	}
}

//- (void) windowDidMove: (NSNotification*) n
//{
//	NSLog(@"Window Moved.");
//}


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
			if (!defaultEmailAppDialog)
			{
				[NSBundle loadNibNamed:@"DefaultEmailApp" owner:self];
			}
			
			[defaultEmailAppDialog center];
			[defaultEmailAppDialog makeKeyAndOrderFront:self];
		}		
	}
}

- (GIMainWindow*) mainWindow
{
	for (NSWindow *window in [self windows])
	{
		if ([[window windowController] isKindOfClass:[GIMainWindowController class]])
		{
			return (GIMainWindow*)window;
		}
	}
	return nil;
}




- (void) importFromImportFolder: (NSNotification*) notification
{
	unsigned importCount = 0;
	NSString *importPath = [[self.context documentPath] stringByAppendingPathComponent:@"Import Queue"];
	OPPersistentObjectContext* context = self.context;

	NSDirectoryEnumerator* e = [[NSFileManager defaultManager] enumeratorAtPath: importPath];
	NSMutableArray* filePaths = [NSMutableArray array];
	NSString* filename;
	while (importCount < 10 && (filename = [e nextObject])) {
		if ([filename hasSuffix: @".gml"]) {
			NSDictionary* attrs = [e fileAttributes];
			if ([attrs objectForKey: NSFileType] == NSFileTypeRegular) {
				NSString* filePath = [importPath stringByAppendingPathComponent: filename];
				if (NSDebugEnabled) NSLog(@"Found %@ to import.", filename);
				
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
	if (NSDebugEnabled) NSLog(@"Imported %u messages.", importedMessages.count);
	if (filename && importCount) {
		// There are more messages in the folder to import.
		// Call self to import the rest.
		[self performSelector: _cmd withObject: notification afterDelay: 0.01];
	}
	
	[context saveChanges];
}

- (void) startImportFromImportFolder: (NSNotification*) notification
{
	[self performSelector: @selector(importFromImportFolder:) withObject: nil afterDelay: 0.0];
	[self performSelector: @selector(importFromImportFolder:) withObject: nil afterDelay: 10.0];
}

- (void) finishLaunching 
{
	registerDefaultDefaults();
	[super finishLaunching];
	
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(startImportFromImportFolder:) name: GIPOPOperationDidStartNotification object: nil];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(importFromImportFolder:) name: GIPOPOperationDidEndNotification object: nil];
	
	[self ensureSomeWindowIsPresent];
	
	[self importFromImportFolder: nil];		
}

- (IBAction)makeDefaultApp:(id)sender
{
	LSSetDefaultHandlerForURLScheme((CFStringRef)@"mailto", (CFStringRef)[[[NSBundle mainBundle] bundleIdentifier] lowercaseString]);
	[defaultEmailAppDialog close];
}

- (void)applicationDidBecomeActive:(NSNotification *)aNotification
{
	static BOOL firstTime = YES;
	
	[self ensureSomeWindowIsPresent];
	
	if (firstTime) {
		[self askForBecomingDefaultMailApplication];
		firstTime = NO;
	}
}

- (IBAction)sendMessagesDueInNearFuture:(id)sender
{
	NSTimeInterval dueInterval = [[NSUserDefaults standardUserDefaults] integerForKey:SoonRipeMessageMinutes] * 60.0;

	for (GIAccount *account in [self.context allObjectsOfClass:[GIAccount class]])
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
			
	for (NSWindow *window in self.windows)
	{
		[window performClose:self];
	}
	
	[GIMessage repairEarliestSendTimes];
	
//	[[GIJunkFilter sharedInstance] writeJunkFilterDefintion];
}

- (void)terminate:(id)sender
{	
	// shutting down persistence:
	[self.context saveChanges];
	[self.context close];	
	
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	
	[super terminate: sender];
}

- (NSArray *)filePathsSortedByCreationDate:(NSArray *)someFilePaths
{
// TODO: Implement filePathsSortedByCreationDate for better mbox restore
    return someFilePaths;
}

- (BOOL) application: (NSApplication*) sender openFile: (NSString*) filename
{
	[self application: sender openFiles: [NSArray arrayWithObject: filename]];
	return YES;
}

- (OPPersistentObjectContext*) context
{
	return [OPPersistentObjectContext defaultContext];
}


- (void)application:(NSApplication *)sender openFiles:(NSArray *)filePaths
{
	filePaths = [self filePathsSortedByCreationDate:filePaths];
	
	NSArray *mboxPaths = [filePaths pathsMatchingExtensions:[NSArray arrayWithObjects:@"mbox", @"mboxfile", @"mbx", nil]];
	NSArray *gmls = [filePaths pathsMatchingExtensions:[NSArray arrayWithObjects:@"gml", nil]];
	OPPersistentObjectContext *context = self.context;
	
	
	GIMainWindowController *windowController = self.mainWindow.windowController;

	@try
	{
		[windowController suspendOutlineViewUpdates];
		
		if (gmls.count) {
			NSArray* messages = [context importGmlFiles: gmls moveOnSuccess: NO];	
			GIMessage* lastMessage = [messages lastObject];
			[windowController showMessage: lastMessage];
		}
		if (mboxPaths.count) {
			NSArray* importGroups = [context importMboxFiles: mboxPaths moveOnSuccess: NO];
			
			[[windowController messageGroupsController] setSelectedItemsPaths: [NSArray arrayWithObject:[NSArray arrayWithObject:[importGroups lastObject]]] byExtendingSelection: NO];
		}
	}
	@finally
	{
		[windowController resumeOutlineViewUpdates];
	}
}

- (IBAction) emptyTrash: (id) sender
{
	NSSet* threads = [[GIMessageGroup trashMessageGroup] threads];
	GIThread* trashedThread;
	while (trashedThread = [threads anyObject]) {
		NSLog(@"Should delete thread %@", trashedThread);
		[trashedThread delete]; // removes trashedThread from threads
	}
	[threads anyObject];
	[self.context saveChanges];
}

- (IBAction) delete: (id) sender
{
	NSLog(@"delete: called.");
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

/*" Creates send operations for accounts with messages that qualify for sending. These are messages that are not blocked (e.g. because they are in the editor) and having flag set (to select send now and queued messages). Creates receive operations for all accounts."*/
- (IBAction)sendAndReceiveInAllAccounts:(id)sender
{
	NSArray *allAccounts = [self.context.allObjectsByClass objectForKey:@"GIAccount"];
	
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
		if (! (sentMessage.flags & OPIsFromMeStatus)) 
		{
			[sentMessage toggleFlags:OPIsFromMeStatus];
			NSLog(@"Sent message not marked as 'from me'. Corrected That.");
		}
		
        // remove from profile:
		GIProfile *sendProfile = [GIProfile sendProfileForMessage:sentMessage];
		[[sendProfile mutableArrayValueForKey:@"messagesToSend"] removeObject:sentMessage];
		
        // remove sent status:
		sentMessage.sendStatus = OPSendStatusNone;
		
		// disconnect thread from queued group:
		[[sentMessage.thread mutableSetValueForKey:@"messageGroups"] removeObject: [GIMessageGroup queuedMessageGroup]];

		if ([sentMessage hasFlags:OPResentStatus]) 
		{
			// create new message with original message id (note: resent message is registered with Resent-Message-Id)
			// this should replace the message that has been resent
			// TODO: test if the original message is replaced
			GIMessage *replacementMessage = [[[GIMessage alloc] initWithInternetMessage:sentMessage.internetMessage appendToAppropriateThread:YES forcedMessageId:nil] autorelease];
			
			// let filters run 'again':
			[self.context addMessageByApplingFilters:replacementMessage];
			
			[sentMessage delete]; // delete sent resent messages - not good!
		} 
		else 
		{
			// Put in appropriate thread (sent message had a single message thread before):
			[GIThread addMessageToAppropriateThread:sentMessage];
			
			// Re-Insert message wherever it belongs:
			[self.context addMessageByApplingFilters:sentMessage];
		}
	}
    
	// mark all messages that were not sent as ready for sending again:
	NSMutableArray *notSentMessages = [[messages mutableCopy] autorelease];
	[notSentMessages removeObjectsInArray:sentMessages];

	for (GIMessage *notSentMessage in notSentMessages) 
	{
		if (notSentMessage.sendStatus == OPSendStatusSending) 
		{
			notSentMessage.sendStatus = OPSendStatusQueuedReady;
		}
	}
	
    [self.context saveChanges];
}

//- (void)applicationDidBecomeActive:(NSNotification *)notification
//{
//	[self.mainWindow.windowController expandDetailView];
//}
//- (void)applicationWillResignActive:(NSNotification *)notification;
//{
//	[self.mainWindow.windowController collapseDetailView];
//}

@end

//- (void) observeValueForKeyPath: (NSString*) keyPath ofObject: (id) object change: (NSDictionary*) change context:(void*) context
//{
//	NSArray* oldValues = [change objectForKey: NSKeyValueChangeOldKey];
//	NSAssert(oldValues.count, @"NSKeyValueChangeOldKey not set.");
//	//[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
//}
//
//
//- (IBAction) testHierarchyObservation: (id) sender
//{
//	GIHierarchyNode* parent = [GIHierarchyNode messageGroupHierarchyRootNode];
//	GIHierarchyNode* child = parent.children.lastObject;
//		
//	[parent addObserver: self forKeyPath: @"children" options: NSKeyValueObservingOptionNew |
//	 NSKeyValueObservingOptionOld context: nil];
//	
//	[[parent mutableArrayValueForKey: @"children"] removeObjectIdenticalTo: child];
//	
//	[parent removeObserver: self forKeyPath: @"children"];
//	[parent release];
//}

