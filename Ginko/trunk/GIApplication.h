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
    IBOutlet GISearchController *searchController;

    BOOL isTerminating;
}

- (NSWindow *)groupsWindow;
- (NSString *)databasePath;

/*" Actions "*/
- (IBAction)saveAction:(id)sender;
- (IBAction)showActivityPanel:(id)sender;
- (IBAction)toggleAutomaticActivityPanel:(id)sender;
- (IBAction)startFulltextIndexingJobIfNeeded:(id)sender;

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

