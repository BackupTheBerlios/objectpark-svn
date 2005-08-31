//  MyDocument.m
//  Ginko3
//
//  Created by Dirk Theisen on 25.11.04.
//  Copyright __MyCompanyName__ 2004 . All rights reserved.

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <Cocoa/Cocoa.h>

#import "Ginko3AppDelegate.h"
#import "G3Message.h"
#import "OPMBoxFile.h"
#import "G3Thread.h"
#import "OPInternetMessage.h"

@implementation Ginko3AppDelegate

- (NSManagedObjectModel*) managedObjectModel
{
    if (managedObjectModel) return managedObjectModel;
	
	NSMutableSet *allBundles = [[NSMutableSet alloc] init];
	[allBundles addObject: [NSBundle mainBundle]];
	[allBundles addObjectsFromArray: [NSBundle allFrameworks]];
    
    managedObjectModel = [[NSManagedObjectModel mergedModelFromBundles: [allBundles allObjects]] retain];
    [allBundles release];
    
    return managedObjectModel;
}

- (NSManagedObjectContext*) managedObjectContext
{
    NSError *error;
    NSString *localizedDescription;
    
    if (managedObjectContext) return managedObjectContext;
    
    NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: [self managedObjectModel]];
    managedObjectContext = [[NSManagedObjectContext alloc] init];
    [managedObjectContext setPersistentStoreCoordinator: coordinator];

    /* Change this path/code to point to your App's data store. */
    NSString *applicationSupportDir = [@"~/Library/Application Support/Ginko3" stringByStandardizingPath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if ( ![fileManager fileExistsAtPath: applicationSupportDir isDirectory: NULL] )
        [fileManager createDirectoryAtPath: applicationSupportDir attributes: nil];
    
    NSURL *url = [NSURL fileURLWithPath: [applicationSupportDir stringByAppendingPathComponent: @"Ginko3.sqlite"]];
    if (![coordinator addPersistentStoreWithType: NSSQLiteStoreType // NSXMLStoreType 
								   configuration: nil 
											 URL: url 
										readOnly: NO 
										   error:&error]) {
        localizedDescription = [error localizedDescription];
        error = [NSError errorWithDomain: @"Ginko3Domain" 
									code: 0		
								userInfo: [NSDictionary dictionaryWithObjectsAndKeys:error, NSUnderlyingErrorKey, [NSString stringWithFormat:@"Store Configuration Failure: %@", ((localizedDescription != nil) ? localizedDescription : @"Unknown Error")], NSLocalizedDescriptionKey, nil]];
    }
    
    return managedObjectContext;
}


- (IBAction) importTestMBox: (id) sender
{
	id context = [self managedObjectContext];
	
	NSLog(@"Created context %@.", context);
	
	id model = [self managedObjectModel];

	NSLog(@"Created model %@.", model);

	
	NSString* boxFilename = [[NSBundle mainBundle] pathForResource: @"test-mbox" ofType: @""];
	NSLog(@"Enumerating mbox '%@'", boxFilename);
	
	OPMBoxFile* box = [OPMBoxFile mboxWithPath: boxFilename];
	NSEnumerator* e = [box messageDataEnumerator];
	NSData* mboxData;
	
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	int maxImport = 10;
	int i = 0;
	while (mboxData = [e nextObject]) {
		//NSLog(@"Found mbox data of length %d", [mboxData length]);
		//OPInternetMessage* importedMessage = [[[OPInternetMessage alloc] initWithTransferData: mboxData] autorelease];
		G3Message* persistentMessage = [G3Message messageWithTransferData: mboxData];
		
		NSLog(@"Found %d. message with MsgId '%@'", i+1, [persistentMessage messageId]);
		
		if (i++>=maxImport) break;
		[pool drain]; // should be last statement in while loop
	}
	[pool release];	
	
	[self saveAction: sender];
}


- (IBAction) saveAction: (id) sender
{
    NSError *error;
    NSString *localizedDescription;
    
    if (![[self managedObjectContext] save: &error]) {
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
