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
#import "G3MessageEditorController.h"
#import "NSManagedObjectContext+Extensions.h"
#import "NSApplication+OPExtensions.h"
#import "GIMessageBase.h"
#import "OPMBoxFile.h"
#import "OPManagedObject.h"
#import "G3Thread.h"
#import "G3MessageGroup.h"
#import <sqlite3.h>
#import "OPJobs.h"


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
    [[[G3MessageEditorController alloc] initNewMessageWithProfile:[[G3Profile profiles] lastObject]] autorelease];
}

- (BOOL)validateSelector:(SEL)aSelector
{
    if (aSelector == @selector(openNewGroupWindow:)) 
    {
        if([self isGroupsDrawerMode])
        {
            return YES;
        }
        else
        {
            return NO;
        }
    }

    return YES;
}

+ (NSArray*) preferredContentTypes
{
    NSArray* types = [[NSUserDefaults standardUserDefaults] objectForKey: ContentTypePreferences];
    return types;
}

- (BOOL) validateMenuItem: (id <NSMenuItem>) menuItem
{
    return [self validateSelector: [menuItem action]];
}

- (void) restoreOpenWindowsFromLastSession
{
    NSLog(@"-[GIApplication restoreOpenWindowsFromLastSession] (not yet implemented)");
    // TODO
}

- (NSManagedObjectModel*) managedObjectModel
{	
	NSMutableSet *allBundles = [[NSMutableSet alloc] init];
	[allBundles addObject: [NSBundle mainBundle]];
	[allBundles addObjectsFromArray: [NSBundle allFrameworks]];
    
    NSManagedObjectModel* managedObjectModel = [NSManagedObjectModel mergedModelFromBundles: [allBundles allObjects]];
    [allBundles release];
    
    return managedObjectModel;
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
		
		if (errorCode = sqlite3_exec(db, /* An open database */
			"CREATE INDEX MY_THREAD_DATE_INDEX ON ZTHREAD (ZDATE);", /* SQL to be executed */
			NULL, /* Callback function */
			NULL, /* 1st argument to callback function */
			&error)) { /* Error msg written here */
			if (error) {
				NSLog(@"Error creating index: %s", error);
			}
		}
	}
	
	sqlite3_close(db);
}

- (NSString *)databasePath
{
    static NSString *path = nil;
    if (!path) path = [[self applicationSupportPath] stringByAppendingPathComponent:@"GinkoBase.sqlite"];
    return path;
}

- (NSManagedObjectContext*) newManagedObjectContext
/* Creates a new context according to the model. The result is not autoreleased! */
{
    NSError*  error;
    NSString* localizedDescription;
	
    NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: [self managedObjectModel]];
    NSManagedObjectContext* managedObjectContext = [[NSManagedObjectContext alloc] init];
    [managedObjectContext setPersistentStoreCoordinator: coordinator];
	[coordinator release];
    /* Change this path/code to point to your App's data store. */
    //NSString *applicationSupportDir = [@"~/Library/Application Support/Ginko3" stringByStandardizingPath];
    //NSFileManager* fileManager = [NSFileManager defaultManager];	
	
    if (![coordinator addPersistentStoreWithType: NSSQLiteStoreType // NSXMLStoreType
                                   configuration: nil
                                             URL: [NSURL fileURLWithPath:[self databasePath]]
                                         options: nil
                                           error: &error]) 
    {
        localizedDescription = [error localizedDescription];
        error = [NSError errorWithDomain: @"Ginko3Domain" 
									code: 0		
								userInfo: [NSDictionary dictionaryWithObjectsAndKeys:error, NSUnderlyingErrorKey, [NSString stringWithFormat:@"Store Configuration Failure: %@", ((localizedDescription != nil) ? localizedDescription : @"Unknown Error")], NSLocalizedDescriptionKey, nil]];
    }
	//NSLog(@"Store: %@", [[coordinator persistentStores] lastObject]);	
	return managedObjectContext;
}

- (NSManagedObjectContext*) initialManagedObjectContext
{
    NSError*   error;
    NSString* path      = [[self applicationSupportPath] stringByAppendingPathComponent: @"GinkoBase.sqlite"];
    BOOL isNewlyCreated = ![[NSFileManager defaultManager] fileExistsAtPath: path]; // used to configure DB using SQL below (todo)
    
    NSManagedObjectContext* managedObjectContext = [self newManagedObjectContext];
    
    if (isNewlyCreated) {
        error = nil;
        [managedObjectContext save: &error];
        [managedObjectContext release]; // get rid of it
        NSLog(@"Commit errors: %@", error);
        [self configureDatabaseAtPath: path];
        managedObjectContext = [self newManagedObjectContext];
    }
    
    [[managedObjectContext undoManager] setLevelsOfUndo:0];
    return [managedObjectContext autorelease];
}

- (void) awakeFromNib
{
    [NSManagedObjectContext setDefaultContext: [self initialManagedObjectContext]];
    
    [self setDelegate: self];
    [self restoreOpenWindowsFromLastSession];
    
    // Some statistical messsages:
    //	NSManagedObjectContext* context = [NSManagedObjectContext defaultContext];	
    //NSArray *allMessages = [G3Message allObjects];
    //G3Message *aMessage  = [allMessages lastObject];
    
    //NSLog(@"MessageBase contains %d message objects in %d threads.", [allMessages count], [[G3Thread allObjects] count]);
    
    //	NSLog(@"message = %@", [NSString stringWithData:[aMessage transferData] encoding:NSASCIIStringEncoding]);
    //NSLog(@"last message = %@", aMessage);
    //NSLog(@"All Groups %@", [G3MessageGroup allObjects]);
}

- (BOOL) isGroupsDrawerMode
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:GroupsDrawerMode];
}

- (NSWindow*) standaloneGroupsWindow
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
	//NSLog(@"Supergroup is %@", [G3MessageGroup superGroup]);

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

- (IBAction) importTestMBox: (id) sender
{
    NSString *boxFilename = [[NSBundle mainBundle] pathForResource:@"test-mbox" ofType:@""];
    //NSString *boxFilename = @"/Users/axel/Desktop/macosx-dev.mbox.txt";
    NSMutableDictionary *jobArguments = [NSMutableDictionary dictionary];
    
    [jobArguments setObject:boxFilename forKey:@"mboxFilename"];
    [jobArguments setObject:[NSManagedObjectContext defaultContext] forKey:@"parentContext"];
    
    [OPJobs scheduleJobWithName:@"mbox import" target:[[[GIMessageBase alloc] init] autorelease] selector:@selector(importMessagesFromMboxFileJob:) arguments:jobArguments synchronizedObject:nil];
  
//    OPMBoxFile *box = [OPMBoxFile mboxWithPath: boxFilename];
    
//    [GIMessageBase importFromMBoxFile: box];		
}


- (IBAction) saveAction: (id) sender
{
    NSError *error;
    NSString *localizedDescription;
    
    NSLog(@"committing database objects");
    
    if (! [(NSManagedObjectContext *)[NSManagedObjectContext defaultContext] save: &error]) {
        localizedDescription = [error localizedDescription];
        error = [NSError errorWithDomain: @"Ginko3Domain" code: 0 userInfo: [NSDictionary dictionaryWithObjectsAndKeys:error, NSUnderlyingErrorKey, [NSString stringWithFormat:@"Error saving: %@", ((localizedDescription != nil) ? localizedDescription : @"Unknown Error")], NSLocalizedDescriptionKey, nil]];
        [[NSApplication sharedApplication] presentError:error];
    }
}

- (void) applicationWillTerminate: (NSNotification* )notification
{
    [self saveAction:self];
}



@end
