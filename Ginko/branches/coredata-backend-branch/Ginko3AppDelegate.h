//  MyDocument.m
//  Ginko3
//
//  Created by Dirk Theisen on 25.11.04.
//  Copyright __MyCompanyName__ 2004 . All rights reserved.

@interface Ginko3AppDelegate : NSObject 
{
    IBOutlet NSWindow* window;
    
    NSManagedObjectModel* managedObjectModel;
    NSManagedObjectContext* managedObjectContext;
}

- (NSManagedObjectModel*) managedObjectModel;
- (NSManagedObjectContext*) managedObjectContext;

- (IBAction) importTestMBox: (id) sender;


- (IBAction) saveAction: sender;

@end
