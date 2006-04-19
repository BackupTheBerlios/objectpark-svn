//
//  GIApplication.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on Mon Jul 19 2004.
//  Copyright (c) 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "GIApplication.h"
#import "GIThreadListController.h"
#import "GIUserDefaultsKeys.h"
#import "GIThreadListController.h"
#import "GIMessageEditorController.h"
#import "NSApplication+OPExtensions.h"
#import "GIMessageBase.h"
#import "OPMBoxFile.h"
#import "GIThread.h"
#import "GIMessageGroup.h"
#import "GISearchController.h"
#import <sqlite3.h>
#import "OPJobs.h"
#import "GIActivityPanelController.h"
#import "GIPOPJob.h"
#import "GISMTPJob.h"
#import "GIAccount.h"
#import <Foundation/NSDebug.h>
#import "GIMessage.h"
#import "GIGroupListController.h"
#import "GIPhraseBrowserController.h"
#import <OPPreferences/OPPreferences.h>
#import "OPObjectPair.h"
#import "NSArray+Extensions.h"
#import "MailToCommand.h"
#import <ApplicationServices/ApplicationServices.h>
#include <unistd.h>

#import <OPDebug/OPLog.h>
#import <JavaVM/JavaVM.h>
#import "GIFulltextIndex.h"

@implementation GIApplication

NSNumber* yesNumber = nil;


+ (void)load
    {
    static BOOL didLoad = NO;
    
    if (didLoad == YES)
        return;
        
	yesNumber = [NSNumber numberWithBool: YES];
	
    didLoad = YES;
    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        
    [[OPLog sharedInstance] addAspectsFromEnvironmentWithDefinitionsFromFile:[[NSBundle bundleForClass:NSClassFromString(@"GIApplication")] pathForResource: @"OPL-Configuration" ofType:@"plist"]];
    
    [pool release];
    }


+ (void)initialize
{
    registerDefaultDefaults();
    NSAssert([[NSUserDefaults standardUserDefaults] objectForKey:ContentTypePreferences], @"Failed to register default Preferences.");
    [GIActivityPanelController initialize];
}

- (IBAction)addressbook:(id)sender
/*" Launches the Addressbook application. "*/
{
    [[NSWorkspace sharedWorkspace] launchApplication:@"Address Book"];
}

- (IBAction)newMessage:(id)sender
{
    // determine message group of frontmost window:
    GIProfile *groupProfile = nil;
    
    id frontmostWindowDelegate = [[NSApp mainWindow] delegate];
    
    if ([frontmostWindowDelegate respondsToSelector:@selector(group)])
    {
        groupProfile = [[frontmostWindowDelegate group] defaultProfile];
    }
    
    [[[GIMessageEditorController alloc] initNewMessageWithProfile:groupProfile] autorelease];
}

- (BOOL)validateSelector:(SEL)aSelector
{
    return YES;
}

+ (NSArray *)preferredContentTypes
{
    NSArray *types = [[NSUserDefaults standardUserDefaults] objectForKey:ContentTypePreferences];
    return types;
}

- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem
{
    if ([menuItem action] == @selector(toggleAutomaticActivityPanel:)) 
	{
        if ([[NSUserDefaults standardUserDefaults] boolForKey:AutomaticActivityPanelEnabled]) 
		{
            [menuItem setState:NSOnState];
        } 
		else 
		{
            [menuItem setState:NSOffState];
        }
        return YES;
    }
	else if ([menuItem action] == @selector(sendMessagesDueInNearFuture:)) 
	{
		int soonRipeMinutes = [[NSUserDefaults standardUserDefaults] integerForKey:SoonRipeMessageMinutes];
		if ([GIAccount anyMessagesRipeForSendingAtTimeIntervalSinceNow:(NSTimeInterval)soonRipeMinutes * 60.0])
		{
			[menuItem setTitle:[NSString stringWithFormat:NSLocalizedString(@"Send Messages Due in %d Minutes", @"Menu item"), soonRipeMinutes]];
			return YES;
		}
		else
		{
			[menuItem setTitle:[NSString stringWithFormat:NSLocalizedString(@"No Messages Due in %d Minutes", @"Menu item"), soonRipeMinutes]];
			return NO;
		}
	}
    return [self validateSelector:[menuItem action]];
}

- (void) saveOpenWindowsFromThisSession
{
	NSMutableArray* groupNames = [NSMutableArray array];
	NSWindow* win;
    NSEnumerator* enumerator = [[NSApp windows] objectEnumerator];
    while (win = [enumerator nextObject]) {
		GIThreadListController* controller = [win delegate];
        if ([controller isKindOfClass: [GIThreadListController class]]) {
			NSString* groupURL = [[controller group] objectURLString];
			if ([groupURL length]) [groupNames addObject: groupURL];
        }
    }
	[[NSUserDefaults standardUserDefaults] setObject: groupNames forKey: OpenMessageGroups];
}

- (void) restoreOpenWindowsFromLastSession
{
	OPPersistentObjectContext* context = [OPPersistentObjectContext defaultContext];	
	NSArray* groupsToOpen = [[NSUserDefaults standardUserDefaults] objectForKey: OpenMessageGroups];
	
	NSEnumerator* groupEnumerator = [groupsToOpen objectEnumerator];
	NSString* groupURL;
	while (groupURL = [groupEnumerator nextObject]) {
		@try {
			GIMessageGroup* group = [context objectWithURLString: groupURL];
			[GIGroupListController showGroup: group];
		} @catch(NSException* e) {
		}
	}
}

- (void) configureDatabaseAtPath: (NSString*) path
{
	NSLog(@"DB file %@ created.", path);
    
	// add indexes:
	sqlite3* db = NULL;
	sqlite3_open([path UTF8String],   /* Database filename (UTF-8) */
		&db);                /* OUT: SQLite db handle */
	
	if (db) {
        int errorCode;
        char* error;
        NSLog(@"DB opened. Creating additional indexes...");
        
        if (errorCode = sqlite3_exec(db, /* An open database */
            "CREATE UNIQUE INDEX MY_MESSAGE_ID_INDEX ON ZMESSAGE (ZMESSAGEID);", /* SQL to be executed */
            NULL, /* Callback function */
            NULL, /* 1st argument to callback function */
            &error)) { /* Error msg written here */
            if (error) {
                NSLog(@"Error creating index: %s", error);
            }
        }
        // This index is not used by sqlite.            
        //            if (errorCode = sqlite3_exec(db, /* An open database */
        //                "CREATE INDEX MY_THREAD_DATE_INDEX ON ZTHREAD (ZDATE);", /* SQL to be executed */
        //                NULL, /* Callback function */
        //                NULL, /* 1st argument to callback function */
        //                &error)) { /* Error msg written here */
        //                if (error) {
        //                    NSLog(@"Error creating index: %s", error);
        //                }
        //            }
        if (errorCode = sqlite3_exec(db, /* An open database */
            "PRAGMA default_cache_size = 8000;", /* SQL to be executed */
            NULL, /* Callback function */
            NULL, /* 1st argument to callback function */
            &error)) { /* Error msg written here */
            if (error) {
                NSLog(@"Error setting cache size: %s", error);
            }
        }

	}

	sqlite3_close(db);
}

- (NSString*) databasePath
{
    static NSString *path = nil;
    if (!path) path = [[self applicationSupportPath] stringByAppendingPathComponent: @"MessageBase.sqlite"];
    return path;
}

- (OPPersistentObjectContext*) initialPersistentObjectContext
{
    //NSError*   error;
    NSString* path      = [[self applicationSupportPath] stringByAppendingPathComponent: @"MessageBase.sqlite"];
    //BOOL isNewlyCreated = ![[NSFileManager defaultManager] fileExistsAtPath: path]; // used to configure DB using SQL below (todo)
    
	//NSAssert(!isNewlyCreated, @"Please supply an old database file. DB creation not implemented.");
	
    OPPersistentObjectContext* persistentObjectContext = [[OPPersistentObjectContext alloc] init];
	[persistentObjectContext setDatabaseConnectionFromPath: path];
	[persistentObjectContext checkDBSchemaForClasses: @"GIMessage,GIAccount,GIThread,GIMessageGroup,GIProfile,GIMessageData"];
    
    return [persistentObjectContext autorelease];
}

- (void)prefpaneDidEndEditing:(NSNotification *)notification
{
	[self saveAction:nil];
}

- (void)awakeFromNib
{
    [self setDelegate:self];
	    
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prefpaneDidEndEditing:) name:OPPreferencePaneDidEndEditing object:nil];
		
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(jobFinished:) name:OPJobDidFinishNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(SMTPJobFinished:) name:OPJobDidFinishNotification object:[GISMTPJob jobName]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fulltextIndexJobFinished:) name:OPJobDidFinishNotification object:[GIFulltextIndex jobName]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(POPJobFinished:) name:OPJobDidFinishNotification object:[GIPOPJob jobName]];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(importJobFinished:) name:OPJobDidFinishNotification object:MboxImportJobName];

    // Some statistical messsages:
    //OPPersistentObjectContext* context = [OPPersistentObjectContext threadContext];	
    //NSArray*allMessages = [GIMessage allObjects];
    //GIMessage *aMessage  = [allMessages lastObject];
    
    //NSLog(@"MessageBase contains %d message objects in %d threads.", [allMessages count], [[GIThread allObjects] count]);
    
    //	NSLog(@"message = %@", [NSString stringWithData:[aMessage transferData] encoding:NSASCIIStringEncoding]);
    //NSLog(@"last message = %@", aMessage);
    [OPPersistentObjectContext setDefaultContext:[self initialPersistentObjectContext]];

    [GIMessageGroup ensureDefaultGroups];
    //NSLog(@"All Groups %@", [GIMessageGroup allObjects]);
    [GIMessage resetSendStatus];
	
	[[[GIGroupListController alloc] init] autorelease]; // opens group list
    [self restoreOpenWindowsFromLastSession];

        // Make sure, we receive NSManagedObjectContextDidSaveNotifications:
    //[[NSNotificationCenter defaultCenter] addObserver: [OPPersistentObjectContext class] selector: @selector(objectsDidChange2:) 
    //                                             name: NSManagedObjectContextDidSaveNotification 
    //                                           object: nil];  
	[self askForBecomingDefaultMailApplication];
}

- (NSWindow *)groupsWindow
{
    NSWindow *win;
    NSEnumerator *enumerator = [[NSApp windows] objectEnumerator];
	Class glcc = [GIGroupListController class];

    while (win = [enumerator nextObject]) 
    {
        if ([[win delegate] isKindOfClass:glcc]) 
        {
			return win;
        }
    }
    return nil;
}

- (void)applicationDidBecomeActive:(NSNotification *)aNotification
{
    if (![self groupsWindow])
    {
        [[[GIGroupListController alloc] init] autorelease]; // opens group list
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
/*" On launch, opens a group window. "*/
{
    [self applicationDidBecomeActive:aNotification];
    [OPJobs setMaxThreads:16];
    [self startFulltextIndexingJobIfNeeded:self];
	[GIAccount resetAccountRetrieveAndSendTimers];
}

- (NSArray *)filePathsSortedByCreationDate:(NSArray *)someFilePaths
{
#warning implement for better mbox restore
    return someFilePaths;
}

- (IBAction)importMboxFile:(id)sender
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
    
    if (result == NSOKButton) 
    {
        [[NSUserDefaults standardUserDefaults] setObject:[oPanel directory] forKey:ImportPanelLastDirectory];
        
        NSArray *filesToOpen = [self filePathsSortedByCreationDate:[oPanel filenames]];

        if ([filesToOpen count]) 
        {
            [self showActivityPanel:sender];
            
            NSEnumerator *enumerator = [filesToOpen objectEnumerator];
            NSString *boxFilename;
            
            while (boxFilename = [enumerator nextObject]) {
                NSMutableDictionary *jobArguments = [NSMutableDictionary dictionary];
                
				[jobArguments setObject: boxFilename forKey: @"mboxFilename"];
				[jobArguments setObject: [OPPersistentObjectContext threadContext] forKey: @"parentContext"];
                [jobArguments setObject: yesNumber forKey: @"copyOnly"];
				
                [OPJobs scheduleJobWithName:MboxImportJobName target:[[[GIMessageBase alloc] init] autorelease] selector:@selector(importMessagesFromMboxFileJob:) argument:jobArguments synchronizedObject:@"mbox import"];
            }
        }
    }    
}

- (IBAction)saveAction:(id)sender
{
	@try {
		[[OPPersistentObjectContext threadContext] saveChanges];
	} @catch (NSException* exception) {
		NSString* localizedDescription;
//        NSLog(@"Commit error: Affected objects = %@\nchanged objects = %@\nDeleted objects = %@", [[exception userInfo] objectForKey:NSAffectedObjectsErrorKey], [[OPPersistentObjectContext threadContext] changedObjects], [[OPPersistentObjectContext threadContext] deletedObjects]);
        localizedDescription = [exception description]; // todo: was: localizedDescription!
        NSError* error = [NSError errorWithDomain: @"GinkoDomain" code: 0 userInfo: [NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat: @"Error saving: %@", ((localizedDescription != nil) ? localizedDescription : @"Unknown Error")], NSLocalizedDescriptionKey, nil]];
        [self presentError: error];
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

	isTerminating = YES;

    [OPJobs suspendPendingJobs];
    NSArray *runningJobs = [OPJobs runningJobs];
    
    if ([runningJobs count])
    {
        enumerator = [runningJobs objectEnumerator];
        NSNumber *jobId;
        
        while (jobId = [enumerator nextObject])
        {
            [OPJobs suggestTerminatingJob:jobId];
        }
        
        result = NSTerminateLater;
    }
    
    return result;
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
	[self saveOpenWindowsFromThisSession];
	
	[[self windows] makeObjectsPerformSelector:@selector(performClose:) withObject:self];
	
    [self saveAction:self];
	
	[GIMessage repairEarliestSendTimes];
	
    // temporary hack:
    [GIMessage sweepBadMessages];
	
	[[OPPersistentObjectContext defaultContext] close];
}

- (void)stop:(id)sender
{
	[[OPPersistentObjectContext defaultContext] close];
	[super stop:sender];
}

- (void)jobFinished:(NSNotification *)aNotification
{
    if (isTerminating)
    {
        if ([[OPJobs runningJobs] count] == 0)
        {
			// let other notification listeners clean up properly...hence the little delay:
			[self replyToApplicationShouldTerminate:YES];
        }
    }
}

- (void)abortApplicationTerminate
{
    isTerminating = NO;
    [OPJobs resumePendingJobs];
    [self replyToApplicationShouldTerminate:NO];
}

- (void)POPJobFinished:(NSNotification *)aNotification
{
    OPDebugLog(OPJOBS, OPINFO, @"POPJobFinished");
    
    NSNumber *jobId = [[aNotification userInfo] objectForKey:@"jobId"];
    NSParameterAssert(jobId != nil && [jobId isKindOfClass:[NSNumber class]]);
    
    NSException *exception = [[aNotification userInfo] objectForKey:@"exception"];
    
    if (exception)
    {
        NSString *localizedDescription = [[exception userInfo] objectForKey:NSLocalizedDescriptionKey];
        
        NSError *error = [NSError errorWithDomain:@"GinkoDomain" code:0 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:localizedDescription ? localizedDescription : [exception reason], NSLocalizedDescriptionKey, 
            nil]];
        [[NSApplication sharedApplication] presentError:error];

        return;
    }
    
    NSString *mboxPath = [OPJobs resultForJob:jobId];
    [OPJobs removeFinishedJob:jobId]; // clean up
    
    if (mboxPath)
    {
        NSParameterAssert([mboxPath isKindOfClass:[NSString class]]);
     
        // import mbox at path mboxPath:
        NSMutableDictionary *jobArguments = [NSMutableDictionary dictionary];
                
        [jobArguments setObject:mboxPath forKey:@"mboxFilename"];
        [jobArguments setObject:[OPPersistentObjectContext threadContext] forKey: @"parentContext"];
        
        [OPJobs scheduleJobWithName:MboxImportJobName target:[[[GIMessageBase alloc] init] autorelease] selector:@selector(importMessagesFromMboxFileJob:) argument:jobArguments synchronizedObject:@"mbox import"];
    }
}

- (void)importJobFinished:(NSNotification *)aNotification
{
    OPDebugLog(OPJOBS, OPINFO, @"importJobFinished");
    
    NSNumber *jobId = [[aNotification userInfo] objectForKey: @"jobId"];
    NSParameterAssert(jobId != nil && [jobId isKindOfClass:[NSNumber class]]);
    
    [OPJobs removeFinishedJob:jobId]; // clean up
    
    [self saveAction:self];
    
    [self startFulltextIndexingJobIfNeeded:self];
}

- (IBAction)startFulltextIndexingJobIfNeeded:(id)sender
{
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"fulltextSearchDisabled"])
    {
        if (![[OPJobs pendingJobsWithName:[GIFulltextIndex jobName]] count])
        {            
            //NSArray *messagesToAdd = [GIMessage messagesToAddToFulltextIndexWithLimit:1000]; // perform this expensive operation in background thread!!
            //NSArray *messagesToRemove = [GIMessage messagesToRemoveFromFulltextIndexWithLimit:250]; // perform this expensive operation in background thread!
            
			//            if ([messagesToAdd count] || [messagesToRemove count]) 
			//            {
			[GIFulltextIndex fulltextIndexInBackgroundAdding:nil removing:nil];
			//            }
        }
    }
}

- (void) fulltextIndexJobFinished:(NSNotification *)aNotification
{
    OPDebugLog(OPJOBS, OPINFO, @"fulltextIndexJobFinished");
    NSNumber *jobId = [[aNotification userInfo] objectForKey:@"jobId"];
    NSParameterAssert(jobId != nil && [jobId isKindOfClass:[NSNumber class]]);
	BOOL didIndexSomeMessages = [[OPJobs resultForJob:jobId] boolValue];

	[OPJobs removeFinishedJob:jobId]; // clean up
    	
	if (didIndexSomeMessages) [self startFulltextIndexingJobIfNeeded:self];
}

- (void)SMTPJobFinished:(NSNotification *)aNotification
{
    OPDebugLog(OPJOBS, OPINFO, @"SMTPJobFinished");
    
    NSNumber *jobId = [[aNotification userInfo] objectForKey: @"jobId"];
    NSParameterAssert(jobId != nil && [jobId isKindOfClass:[NSNumber class]]);
    
    NSDictionary *result = [OPJobs resultForJob:jobId];

	// Set status of all messages with OPSendStatusSending back to OPSendStatusQueuedReady:
	NSEnumerator *enumerator = [[GIProfile allObjects] objectEnumerator];
	GIProfile *profile;
	while (profile = [enumerator nextObject]) 
    {
		NSEnumerator *messagesToSendEnumerator = [[profile valueForKey: @"messagesToSend"] objectEnumerator];
		GIMessage *message;
		while (message = [messagesToSendEnumerator nextObject]) 
        {
			if ([message sendStatus] == OPSendStatusSending) 
            {
				[message setSendStatus: OPSendStatusQueuedReady];
			}
		}            
	}
	
	[OPJobs removeFinishedJob:jobId]; // clean up
	
	// Process all messages sent successfully:
	
	NSArray *messages = [result objectForKey: @"messages"];
	NSAssert(messages != nil, @"result does not contain 'messages'");
	
	NSArray *sentMessages = [result objectForKey: @"sentMessages"];
	NSAssert(sentMessages != nil, @"result does not contain 'sentMessages'");
	
	enumerator = [sentMessages objectEnumerator];
	GIMessage *message;
	
	while (message = [enumerator nextObject]) 
    {
        // remove account info:
        [message setValue:nil forKey:@"sendProfile"];
        // remove sent status:
		[message setSendStatus:OPSendStatusNone];
		// Disconnect message from its dummy thread:
		[[message valueForKey: @"thread"] removeValue:[GIMessageGroup queuedMessageGroup] forKey:@"groups"];
		[message setValue:nil forKey:@"thread"];
		// Re-Insert message wherever it belongs:
		[GIMessageBase addMessage:message];
	}
    
    [self saveAction:self];
}

- (IBAction)sendAndReceiveInAllAccounts:(id)sender
/*" Creates send jobs for accounts with messages that qualify for sending. That are messages that are not blocked (e.g. because they are in the editor) and having flag set (to select send now and queued messages). Creates receive jobs for all accounts."*/
{
	[GIAccount resetAccountRetrieveAndSendTimers];
	[[GIAccount allObjects] makeObjectsPerformSelector:@selector(send)];
	[GIAccount resetAccountRetrieveAndSendTimers];
	[[GIAccount allObjects] makeObjectsPerformSelector:@selector(receive)];
}

- (IBAction)sendMessagesDueInNearFuture:(id)sender
{
	NSEnumerator *enumerator = [[GIAccount allObjects] objectEnumerator];
	GIAccount *account;
	NSTimeInterval dueInterval = [[NSUserDefaults standardUserDefaults] integerForKey:SoonRipeMessageMinutes] * 60.0;
	while (account = [enumerator nextObject]) 
	{
		[account sendMessagesRipeForSendingAtTimeIntervalSinceNow:dueInterval];
	}
}

- (IBAction)showActivityPanel:(id)sender
{
	NSWindow *aWindow = [[GIActivityPanelController sharedInstance] window];
	
	if ([aWindow isVisible]) [aWindow close];
	else [aWindow orderFront:nil];
}

- (IBAction)showPhraseBrowser:(id)sender
{
    [GIPhraseBrowserController showPhraseBrowserForTextView:nil];
}

- (IBAction)toggleAutomaticActivityPanel:(id)sender
{
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setBool:![ud boolForKey: AutomaticActivityPanelEnabled] forKey:AutomaticActivityPanelEnabled];
    
    // Hides activity panel if needed:
    [GIActivityPanelController updateData];
}

- (IBAction) emptyTrashMailbox: (id) sender
{
    GIMessageGroup* trashgroup = [GIMessageGroup trashMessageGroup];
    OPFaultingArray* threads = [trashgroup valueForKey: @"threadsByDate"];
    GIThread* thread;
    int counter = 0;
    
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    
    while (thread = [threads lastObject]) {
		 // Remove thread from source group:
        [thread removeValue: trashgroup forKey: @"groups"];
        
        if ([[thread valueForKey: @"groups"] count] == 0) {
            [thread delete];
        }
        
        counter += 1;
        
        if ((counter % 100) == 0) {
            //[self saveAction:self];
            [pool release]; pool = [[NSAutoreleasePool alloc] init];
        }
    }    

    [self saveAction: self];
    
	[GIFulltextIndex fulltextIndexInBackgroundAdding:nil removing:[GIMessage deletedMessages]];
    
    [pool release];
}

- (BOOL)isGinkoStandardMailApplication
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
		if (![self isGinkoStandardMailApplication])
		{
			[standardAppWindow center];
			[standardAppWindow makeKeyAndOrderFront:self];
		}		
	}
}

- (IBAction)makeGinkoStandardApp:(id)sender
{
	LSSetDefaultHandlerForURLScheme((CFStringRef)@"mailto", (CFStringRef)[[[NSBundle mainBundle] bundleIdentifier] lowercaseString]);
	[standardAppWindow close];
}

- (IBAction)dontChangeStandardApp:(id)sender
{
	[standardAppWindow close];
}

@end

@implementation GIApplication (ScriptingSupport)

// Scripting Support

- (NSString *)userEmail
{
    return [[GIProfile defaultProfile] valueForKey:@"mailAddress"];
}

@end
