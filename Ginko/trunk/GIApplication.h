//
//  GIApplication.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on Mon Jul 19 2004.
//  Copyright (c) 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <AddressBook/AddressBook.h>
#import "OPPersistence.h"

@class GISearchController;

#define GIApp ((GIApplication *)NSApp)

extern NSNumber* yesNumber;

@interface GIApplication : NSApplication 
{
	IBOutlet NSWindow *standardAppWindow;

    BOOL isTerminating;
}

+ (NSThread *)mainThread;

- (BOOL)isGinkoStandardMailApplication;
- (void)askForBecomingDefaultMailApplication;

- (NSWindow *)groupsWindow;
- (NSString *)databasePath;

/*" Actions "*/
- (IBAction)saveAction:(id)sender;
- (IBAction)showActivityPanel:(id)sender;
- (IBAction)toggleAutomaticActivityPanel:(id)sender;
- (IBAction)startFulltextIndexingJobIfNeeded:(id)sender;

- (IBAction)makeGinkoStandardApp:(id)sender;
- (IBAction)dontChangeStandardApp:(id)sender;

- (IBAction)sendMessagesDueInNearFuture:(id)sender;

/*" GPG support "*/
- (BOOL)hasGPGAccess;

@end

@interface GIApplication (ScriptingSupport)

//- accounts;
//- valueInAccountsWithName:;
- (NSString *)userEmail;
	//- messageEditors;
	//- (void)insertInMessageEditors:fp12 atIndex:(unsigned int)fp16;
	//- (void)removeFromMessageEditors:fp12;
	//- composeMessages;
	//- (void)insertInComposeMessages:fp12 atIndex:(unsigned int)fp16;
	//- (void)removeFromComposeMessages:fp12;
	//- objectSpecifierForComposeMessage:fp12;

	//- (void)handleOpenAppleEvent:;

@end

@interface GIApplication (NonModalErrorPresenting)

- (BOOL)nonModalPresentError:(NSError *)error withTimeout:(NSTimeInterval)timeout;

@end