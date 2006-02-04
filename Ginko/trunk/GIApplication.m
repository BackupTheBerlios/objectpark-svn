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

#import <OPDebug/OPLog.h>
#import <JavaVM/JavaVM.h>
#import "GIFulltextIndex.h"

@implementation GIApplication

+ (void)load
    {
    static BOOL didLoad = NO;
    
    if (didLoad == YES)
        return;
        
    didLoad = YES;
    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        
    [[OPLog sharedInstance] addAspectsFromEnvironmentWithDefinitionsFromFile:[[NSBundle bundleForClass:NSClassFromString(@"GIApplication")] pathForResource: @"OPL-Configuration" ofType:@"plist"]];
    
    [pool release];
    }


+ (void) initialize
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
    NSArray* types = [[NSUserDefaults standardUserDefaults] objectForKey: ContentTypePreferences];
    return types;
}

- (BOOL) validateMenuItem: (id <NSMenuItem>) menuItem
{
    if ([menuItem action] == @selector(toggleAutomaticActivityPanel:)) {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:AutomaticActivityPanelEnabled]) {
            [menuItem setState:NSOnState];
        } else {
            [menuItem setState:NSOffState];
        }
        return YES;
    }
    else return [self validateSelector:[menuItem action]];
}

- (void) restoreOpenWindowsFromLastSession
{
    NSLog(@"-[GIApplication restoreOpenWindowsFromLastSession] (not yet implemented)");
    // TODO
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
	
	/*
    if (isNewlyCreated) {
        error = nil;
        [managedObjectContext saveChanges];
        [managedObjectContext release]; // get rid of it
        NSLog(@"Commit errors: %@", error);
        [self configureDatabaseAtPath: path];
        managedObjectContext = [self newManagedObjectContext];
    }
	 */
    
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
	
    [self restoreOpenWindowsFromLastSession];

        // Make sure, we receive NSManagedObjectContextDidSaveNotifications:
    //[[NSNotificationCenter defaultCenter] addObserver: [OPPersistentObjectContext class] selector: @selector(objectsDidChange2:) 
    //                                             name: NSManagedObjectContextDidSaveNotification 
    //                                           object: nil];      
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
    [OPJobs setMaxThreads:4];
    [self startFulltextIndexingJobIfNeeded:self];
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
            
            while (boxFilename = [enumerator nextObject]) 
            {
                NSMutableDictionary *jobArguments = [NSMutableDictionary dictionary];
                
				[jobArguments setObject:boxFilename forKey: @"mboxFilename"];
				[jobArguments setObject:[OPPersistentObjectContext threadContext] forKey: @"parentContext"];
                [jobArguments setObject:[NSNumber numberWithBool:YES] forKey: @"copyOnly"];
				
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
    
    isTerminating = YES;
    
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
    [self saveAction:self];
    
    // temporary hack:
    [GIMessage sweepBadMessages];
}

- (IBAction)getNewMailInAllAccounts:(id)sender
{
    NSEnumerator* enumerator = [[GIAccount allObjects] objectEnumerator];
    GIAccount* account;
    
    while (account = [enumerator nextObject]) {
        if ([account isEnabled]) [GIPOPJob retrieveMessagesFromPOPAccount:account];
    }
}

- (void)jobFinished:(NSNotification *)aNotification
{
    if (isTerminating)
    {
        if ([[OPJobs runningJobs] count] == 0)
        {
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
    if (NSDebugEnabled) NSLog(@"POPJobFinished");
    
    NSNumber *jobId = [[aNotification userInfo] objectForKey: @"jobId"];
    NSParameterAssert(jobId != nil && [jobId isKindOfClass:[NSNumber class]]);
    
    NSException *exception = [[aNotification userInfo] objectForKey: @"exception"];
    
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
                
        [jobArguments setObject:mboxPath forKey: @"mboxFilename"];
        [jobArguments setObject:[OPPersistentObjectContext threadContext] forKey: @"parentContext"];
        
        [OPJobs scheduleJobWithName:MboxImportJobName target:[[[GIMessageBase alloc] init] autorelease] selector:@selector(importMessagesFromMboxFileJob:) argument:jobArguments synchronizedObject:@"mbox import"];
    }
}

- (void)importJobFinished:(NSNotification *)aNotification
{
    if (NSDebugEnabled) NSLog(@"importJobFinished");
    
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
            NSArray *messagesToAdd = [GIMessage messagesToAddToFulltextIndexWithLimit:200000];
            NSArray *messagesToRemove = [GIMessage messagesToRemoveFromFulltextIndexWithLimit:250];
            
            if ([messagesToAdd count] || [messagesToRemove count]) 
            {
                [GIFulltextIndex fulltextIndexInBackgroundAdding:messagesToAdd removing:messagesToRemove];
            }
        }
    }
}

- (void) fulltextIndexJobFinished:(NSNotification *)aNotification
{
    if (NSDebugEnabled) NSLog(@"fulltextIndexJobFinished");
    NSNumber *jobId = [[aNotification userInfo] objectForKey:@"jobId"];
    NSParameterAssert(jobId != nil && [jobId isKindOfClass:[NSNumber class]]);
	[OPJobs removeFinishedJob:jobId]; // clean up
    
	// Write flag-changes to disk:
	[[OPPersistentObjectContext defaultContext] saveChanges];
	
    [self startFulltextIndexingJobIfNeeded:self];
}

- (void)SMTPJobFinished:(NSNotification *)aNotification
{
    if (NSDebugEnabled) NSLog(@"SMTPJobFinished");
    
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
		[message setSendStatus:OPSendStatusNone];
		// Disconnect message from its dummy thread:
		[[message valueForKey: @"thread"] removeValue:[GIMessageGroup queuedMessageGroup] forKey: @"groups"];
		[message setValue:nil forKey: @"thread"];
		// Re-Insert message wherever it belongs:
		[GIMessageBase addMessage:message];
	}
    
    [self saveAction:self];
}

- (void)sendQueuedMessagesWithFlag:(unsigned)flag
/*" Creates send jobs for accounts with messages that qualify for sending. That are messages that are not blocked (e.g. because they are in the editor) and having flag set (to select send now and queued messages). Flag is currently ignored. "*/
{
    // iterate over all profiles:
    NSEnumerator *enumerator = [[GIProfile allObjects] objectEnumerator];
    GIProfile *profile;
    
    while (profile = [enumerator nextObject]) 
    {
        NSEnumerator *messagesToSendEnumerator = [[profile valueForKey: @"messagesToSend"] objectEnumerator];
        GIMessage *message;
        NSMutableArray *messagesQualifyingForSend = [NSMutableArray array];
            
        while (message = [messagesToSendEnumerator nextObject]) 
        {
            if ([message sendStatus] == OPSendStatusQueuedReady) 
            {
				[message setSendStatus:OPSendStatusSending];
                [messagesQualifyingForSend addObject:message];
            }
        }
        
		// something to send for the account?
        if ([messagesQualifyingForSend count]) 
        {
            [GISMTPJob sendMessages:messagesQualifyingForSend viaSMTPAccount:[profile valueForKey: @"sendAccount"]];
        }
    }
}

- (IBAction)sendQueuedMessages:(id)sender
{
    [self sendQueuedMessagesWithFlag:OPSendStatusQueuedReady];
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

@end


