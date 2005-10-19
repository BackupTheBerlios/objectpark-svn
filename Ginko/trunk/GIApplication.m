//
//  GIApplication.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on Mon Jul 19 2004.
//  Copyright (c) 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "GIApplication.h"
#import "G3GroupController.h"
#import "GIUserDefaultsKeys.h"
#import "G3GroupController.h"
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

@implementation GIApplication

+ (void)initialize
{
    registerDefaultDefaults();
    NSAssert([[NSUserDefaults standardUserDefaults] objectForKey:ContentTypePreferences], @"Failed to register default Preferences.");
}

- (IBAction)addressbook:(id)sender
/*" Launches the Addressbook application. "*/
{
    [[NSWorkspace sharedWorkspace] launchApplication:@"Address Book"];
}

- (IBAction)openNewGroupWindow:(id)sender
{
    [[[G3GroupController alloc] initWithGroup:nil] autorelease];
}

- (IBAction)newMessage:(id)sender
{
    [[[GIMessageEditorController alloc] initNewMessageWithProfile:[[GIProfile allObjects] lastObject]] autorelease];
}

- (BOOL)validateSelector:(SEL)aSelector
{
    if (aSelector == @selector(openNewGroupWindow:)) 
    {
        if([self isGroupsDrawerMode]) return YES;
        else return NO;
    }

    return YES;
}

+ (NSArray *)preferredContentTypes
{
    NSArray *types = [[NSUserDefaults standardUserDefaults] objectForKey:ContentTypePreferences];
    return types;
}

- (BOOL)validateMenuItem:(id<NSMenuItem>)menuItem
{
    return [self validateSelector:[menuItem action]];
}

- (void)restoreOpenWindowsFromLastSession
{
    NSLog(@"-[GIApplication restoreOpenWindowsFromLastSession] (not yet implemented)");
    // TODO
}

/*
- (NSManagedObjectModel*) managedObjectModel
{	
	NSMutableSet *allBundles = [[NSMutableSet alloc] init];
	[allBundles addObject: [NSBundle mainBundle]];
	[allBundles addObjectsFromArray: [NSBundle allFrameworks]];
    
    NSManagedObjectModel* managedObjectModel = [NSManagedObjectModel mergedModelFromBundles: [allBundles allObjects]];
    [allBundles release];
    
    return managedObjectModel;
}
*/

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

- (NSString *)databasePath
{
    static NSString *path = nil;
    if (!path) path = [[self applicationSupportPath] stringByAppendingPathComponent: @"MessageBase.sqlite"];
    return path;
}

/*
- (OPPersistentObjectContext*) newManagedObjectContext
// Creates a new context according to the model. The result is not autoreleased! 
{
    NSError*  error;
    NSString* localizedDescription;
    NSString* dbPath = [self databasePath];
    
    BOOL isNewlyCreated = ![[NSFileManager defaultManager] fileExistsAtPath: dbPath]; // used to configure DB using SQL below (todo)
    
    
    //NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: [self managedObjectModel]];
    OPPersistentObjectContext* managedObjectContext = [[OPPersistentObjectContext alloc] init];
    //[managedObjectContext setPersistentStoreCoordinator: coordinator];
    //[coordinator release];
    // Change this path/code to point to your App's data store. 
    //NSString *applicationSupportDir = [@"~/Library/Application Support/Ginko3" stringByStandardizingPath];
    //NSFileManager* fileManager = [NSFileManager defaultManager];	
    
	
    if (![coordinator addPersistentStoreWithType: NSSQLiteStoreType // NSXMLStoreType
                                   configuration: nil
                                             URL: [NSURL fileURLWithPath: dbPath]
                                         options: nil
                                           error: &error]) 
    {
        localizedDescription = [error localizedDescription];
        error = [NSError errorWithDomain: @"Ginko3Domain" 
                                    code: 0		
                                userInfo: [NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"Store Configuration Failure: %@", ((localizedDescription != nil) ? localizedDescription : @"Unknown Error")], NSLocalizedDescriptionKey, nil]];
    }
    //NSLog(@"Store: %@", [[coordinator persistentStores] lastObject]);
    
    // Create Indexes, etc.
    if (isNewlyCreated) {
        [managedObjectContext saveChanges];
        [self configureDatabaseAtPath: dbPath];
        [managedObjectContext release];
        managedObjectContext = [self newManagedObjectContext];
    }
	
    
    //[managedObjectContext setMergePolicy:NSMergeByPropertyStoreTrumpMergePolicy];

    //[[managedObjectContext undoManager] setLevelsOfUndo:0];

    return managedObjectContext;
}
*/

- (OPPersistentObjectContext*) initialPersistentObjectContext
{
    //NSError*   error;
    NSString* path      = [[self applicationSupportPath] stringByAppendingPathComponent: @"GinkoBase.sqlite"];
    BOOL isNewlyCreated = ![[NSFileManager defaultManager] fileExistsAtPath: path]; // used to configure DB using SQL below (todo)
    
	NSAssert(!isNewlyCreated, @"Please supply an old database file. DB creation not implemented.");
	
    OPPersistentObjectContext* persistentObjectContext = [[OPPersistentObjectContext alloc] init];
	[persistentObjectContext setDatabaseConnectionFromPath: path];
	
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

- (void)awakeFromNib
{
    [self setDelegate:self];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(SMTPJobFinished:) name:OPJobDidFinishNotification object:[GISMTPJob jobName]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(POPJobFinished:) name:OPJobDidFinishNotification object:[GIPOPJob jobName]];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(importJobFinished:) name:OPJobDidFinishNotification object:MboxImportJobName];

    // Some statistical messsages:
    //OPPersistentObjectContext* context = [OPPersistentObjectContext threadContext];	
    //NSArray *allMessages = [GIMessage allObjects];
    //GIMessage *aMessage  = [allMessages lastObject];
    
    //NSLog(@"MessageBase contains %d message objects in %d threads.", [allMessages count], [[GIThread allObjects] count]);
    
    //	NSLog(@"message = %@", [NSString stringWithData:[aMessage transferData] encoding:NSASCIIStringEncoding]);
    //NSLog(@"last message = %@", aMessage);
    [OPPersistentObjectContext setDefaultContext: [self initialPersistentObjectContext]];

    [GIMessageGroup ensureDefaultGroups];
    //NSLog(@"All Groups %@", [GIMessageGroup allObjects]);
    
    [self restoreOpenWindowsFromLastSession];

        // Make sure, we receive NSManagedObjectContextDidSaveNotifications:
    //[[NSNotificationCenter defaultCenter] addObserver: [OPPersistentObjectContext class] selector: @selector(objectsDidChange2:) 
    //                                             name: NSManagedObjectContextDidSaveNotification 
    //                                           object: nil];  
    
}


/*
+ (void) initialize
{
    static BOOL initialized = NO;
    if (!initialized) {
        [NSManagedObjectContext setMainThreadContext: [self newManagedObjectContext]];
    }
}
*/

- (BOOL)isGroupsDrawerMode
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:GroupsDrawerMode];
}

- (NSWindow *)standaloneGroupsWindow
{
    NSWindow *win;
    NSEnumerator *enumerator = [[NSApp windows] objectEnumerator];
    
    while (win = [enumerator nextObject])
    {
        if ([[win delegate] isKindOfClass:[G3GroupController class]])
        {
            if ([[win delegate] isStandaloneBoxesWindow])
            {
                return win;
            }
        }
    }
    
    return nil;
}

- (BOOL)hasGroupWindow
{
    NSWindow *win;
    NSEnumerator *enumerator;
    
    enumerator = [[NSApp windows] objectEnumerator];
    while (win = [enumerator nextObject])
    {
        if ([[win delegate] isKindOfClass:[G3GroupController class]])
        {
            if (! [[win delegate] isStandaloneBoxesWindow])
            {
                return YES;
            }
        }
    }
    
    return NO;
}

- (void) applicationDidBecomeActive:(NSNotification *)aNotification
{
	//NSLog(@"Supergroup is %@", [GIMessageGroup superGroup]);

    if ([self isGroupsDrawerMode]) {
        if (! [self hasGroupWindow]) 
        {
            [[[G3GroupController alloc] initWithGroup:nil] autorelease];
        }
    } else {
        if (! [self standaloneGroupsWindow]) {
            [[[G3GroupController alloc] initAsStandAloneBoxesWindow:nil] autorelease];
        }
    }
//#warning leaking memory as hell:
  //  [NSAutoreleasePool enableRelease: NO];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
/*" On launch, opens a group window. "*/
{
    [self applicationDidBecomeActive:aNotification];
    [OPJobs setMaxThreads:4];
}

- (NSArray *)sortFilePathsByCreationDate:(NSArray *)someFilePaths
{
#warning implement for better mbox restore
    return someFilePaths;
}

- (IBAction)importMboxFile:(id)sender
/*" Imports one or more mbox files. Recognizes plain mbox files with extension .mboxfile and .mbx and NeXT/Apple style bundles with the .mbox extension. "*/
{
    int result;
    NSArray *fileTypes = [NSArray arrayWithObjects:@"mboxfile", @"mbox", @"mbx", nil];
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
        
        NSArray *filesToOpen = [self sortFilePathsByCreationDate:[oPanel filenames]];
        if ([filesToOpen count]) 
        {
            [self showActivityPanel:sender];
            
            NSEnumerator *enumerator = [filesToOpen objectEnumerator];
            NSString *boxFilename;
            
            while (boxFilename = [enumerator nextObject])
            {
                NSMutableDictionary *jobArguments = [NSMutableDictionary dictionary];
                
                // support for 'mbox' bundles
                if ([[boxFilename pathExtension] isEqualToString:@"mbox"])
                {
                    boxFilename = [boxFilename stringByAppendingPathComponent:@"mbox"];
                }
                
                [jobArguments setObject:boxFilename forKey:@"mboxFilename"];
                [jobArguments setObject:[OPPersistentObjectContext threadContext] forKey:@"parentContext"];
                [jobArguments setObject:[NSNumber numberWithBool:YES] forKey:@"copyOnly"];
                
                [OPJobs scheduleJobWithName:MboxImportJobName target:[[[GIMessageBase alloc] init] autorelease] selector:@selector(importMessagesFromMboxFileJob:) arguments:jobArguments synchronizedObject:@"mbox import"];
            }
        }
    }    
}

/*
- (NSError*) commitChanges
{
    NSError *error = nil;
    
    NSLog(@"committing database objects");
    
    if (![[OPPersistentObjectContext threadContext] saveChanges]) {
        return error;
    } else {
        return nil;
    }
}
*/

- (IBAction) saveAction: (id) sender
{
	@try {
		[[OPPersistentObjectContext threadContext] saveChanges];
	} @catch (NSException* exception) {
		NSString *localizedDescription;
//        NSLog(@"Commit error: Affected objects = %@\nchanged objects = %@\nDeleted objects = %@", [[exception userInfo] objectForKey:NSAffectedObjectsErrorKey], [[OPPersistentObjectContext threadContext] changedObjects], [[OPPersistentObjectContext threadContext] deletedObjects]);
        localizedDescription = [exception description]; // todo: was: localizedDescription!
        NSError* error = [NSError errorWithDomain: @"Ginko3Domain" code: 0 userInfo: [NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"Error saving: %@", ((localizedDescription != nil) ? localizedDescription : @"Unknown Error")], NSLocalizedDescriptionKey, nil]];
        [self presentError: error];
    }
}

- (void) applicationWillTerminate: (NSNotification* )notification
{
    [self saveAction:self];
}

- (IBAction) openSearchWindow: (id) sender
{
    if (!searchController) {
        [NSBundle loadNibNamed: @"Search" owner: self];   
    }
    [[searchController window] makeKeyAndOrderFront: self];
}

/*
- (void) setSearchController: (GISearchController*) c
{
    [c retain];
    [searchController release];
    searchController = c;
}
*/

- (IBAction)showActivityPanel:(id)sender
{
    [GIActivityPanelController showActivityPanelInteractive: YES];
}

- (IBAction)getNewMailInAllAccounts:(id)sender
{
    NSEnumerator *enumerator = [GIAccount allObjectsEnumerator];
    G3Account *account;
    
    while (account = [enumerator nextObject])
    {
        if ([account isEnabled]) [GIPOPJob retrieveMessagesFromPOPAccount:account];
    }
}

- (void)POPJobFinished:(NSNotification *)aNotification
{
    if (NSDebugEnabled) NSLog(@"POPJobFinished");
    
    NSNumber *jobId = [[aNotification userInfo] objectForKey:@"jobId"];
    NSParameterAssert(jobId != nil && [jobId isKindOfClass:[NSNumber class]]);
    
    NSException *exception = [[aNotification userInfo] objectForKey:@"exception"];
    
    if (exception)
    {
        NSString *localizedDescription = [[exception userInfo] objectForKey:NSLocalizedDescriptionKey];
        
        NSError *error = [NSError errorWithDomain:@"Ginko3Domain" code:0 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
            localizedDescription ? localizedDescription : [exception reason], NSLocalizedDescriptionKey, 
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
                
        [jobArguments setObject: mboxPath forKey: @"mboxFilename"];
        [jobArguments setObject: [OPPersistentObjectContext threadContext] forKey: @"parentContext"];
        
        [OPJobs scheduleJobWithName: MboxImportJobName target: [[[GIMessageBase alloc] init] autorelease] selector:@selector(importMessagesFromMboxFileJob:) arguments: jobArguments synchronizedObject: @"mbox import"];
    }
}

- (void)importJobFinished:(NSNotification *)aNotification
{
    if (NSDebugEnabled) NSLog(@"importJobFinished");
    
    NSNumber *jobId = [[aNotification userInfo] objectForKey:@"jobId"];
    NSParameterAssert(jobId != nil && [jobId isKindOfClass:[NSNumber class]]);
    
    [OPJobs removeFinishedJob:jobId]; // clean up
    
    [self saveAction:self];
}

- (void)SMTPJobFinished:(NSNotification *)aNotification
{
    if (NSDebugEnabled) NSLog(@"SMTPJobFinished");
    
    NSNumber *jobId = [[aNotification userInfo] objectForKey:@"jobId"];
    NSParameterAssert(jobId != nil && [jobId isKindOfClass:[NSNumber class]]);
    
    NSDictionary *result = [OPJobs resultForJob:jobId];
    NSAssert1(result != nil, @"no result for job with id %@", jobId);
    
    [OPJobs removeFinishedJob:jobId]; // clean up
    
    NSArray *messages = [result objectForKey:@"messages"];
    NSAssert(messages != nil, @"result does not contain 'messages'");
    
    NSArray *sentMessages = [result objectForKey:@"sentMessages"];
    NSAssert(sentMessages != nil, @"result does not contain 'sentMessages'");

    NSEnumerator *enumerator = [sentMessages objectEnumerator];
    GIMessage *message;
    
    while (message = [enumerator nextObject])
    {
        [message removeFlags:OPDraftStatus | OPQueuedStatus];
        [GIMessageBase removeDraftMessage:message];
        [GIMessageBase addSentMessage:message];
        
        /*    
            [messageCenter performSelector:@selector(addRecipientsToLRUMailAddresses:)
                                withObject:message
                                  inThread:parentThread];
        */
    }
    
    [messages makeObjectsPerformSelector:@selector(resetSendJobStatus)];
    [self saveAction:self];
}

- (void)sendQueuedMessagesWithFlag:(unsigned)flag
/*" Creates send jobs for accounts with messages that qualify for sending. That are messages that are not blocked (e.g. because they are in the editor) and having flag set (to select send now and queued messages). "*/
{
    // iterate over all profiles:
    NSEnumerator *enumerator = [[GIProfile allObjects] objectEnumerator];
    GIProfile *profile;
    
    while (profile = [enumerator nextObject])
    {
        NSEnumerator *messagesToSendEnumerator = [[profile valueForKey:@"messagesToSend"] objectEnumerator];
        GIMessage *message;
        NSMutableArray *messagesQualifyingForSend = [NSMutableArray array];
            
        while (message = [messagesToSendEnumerator nextObject])
        {
            if (![message hasFlags:OPSendingBlockedStatus] && ![message hasFlags:OPDraftStatus] && [message hasFlags:OPQueuedStatus])
            {
                [messagesQualifyingForSend addObject:message];
            }
        }
        
        if ([messagesQualifyingForSend count]) // something to send for the account?
        {
            [messagesQualifyingForSend makeObjectsPerformSelector:@selector(setSendJobStatus)];
            [GISMTPJob sendMessages:messagesQualifyingForSend viaSMTPAccount:[profile valueForKey: @"sendAccount"]];
        }
    }
}

- (IBAction)sendQueuedMessages:(id)sender
{
    [self sendQueuedMessagesWithFlag:OPQueuedStatus];
}

@end
