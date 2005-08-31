//
//  GroupController.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on Fri Jul 23 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "GroupController.h"
#import "GIApplication.h"
#import "G3Message.h"


@implementation GroupController





- (id) init
{
    return [[super init] retain];
}


- (id) initWithGroup: (G3MessageGroup*) aGroup;
{
    if (self = [self init]) {
        group = [aGroup retain];
        [NSBundle loadNibNamed: @"MessageGroup" owner: self];
        NSLog(@"%@ Group: %@", self, group);
        [[tabView window] setTitle: [group name]];
    }
    return self;
}

+ (id) controllerWithGroup: (G3MessageGroup*) aGroup;
{
    return [[[self alloc] initWithGroup: aGroup] autorelease];
}

- (void) windowWillClose: (NSNotification*) notification 
{
    [self release];
}

- (void) dealloc
{
    [displayedMessage release];

    [super dealloc];
}

- (void) awakeFromNib
{
    [tableView setDataSource: self];  
    [tableView setTarget: self];
    [tableView setDoubleAction: @selector(openSelection:)];
}


- (id) tableView: (NSTableView*) aTableView
    objectValueForTableColumn: (NSTableColumn*) aTableColumn
             row: (int) rowIndex

{
    G3Thread* thread = [[group threads] objectAtIndex: rowIndex];
    id theValue = [thread primitiveValueForKey: [aTableColumn identifier]];
    
    /*
        theValue = [queryResult objectAtRow: rowIndex column: columnIndex];
        if ([[aTableColumn identifier] isEqualToString: @"date"]) {
            // Convert the date from seconds since 1970 to date object:
            theValue = [NSCalendarDate dateWithTimeIntervalSince1970: [theValue floatValue]];

     */
    return theValue;
}

/*
- (void) tableView: (NSTableView*) aTableView
    setObjectValue: anObject
    forTableColumn: (NSTableColumn*) aTableColumn
               row: (int) rowIndex
{

}
*/

- (G3Message*) displayedMessage
{
    return displayedMessage;
}

- (void) setDisplayedMessage: (G3Message*) newMessage
{
    if (![[newMessage oid] isEqual: [displayedMessage oid]]) {
        [displayedMessage release];
        displayedMessage = [newMessage retain];
        
        NSAttributedString* bodyString = [displayedMessage contentAsAttributedString];
        
        NSLog(@"Current message to display: %@", [bodyString string]);

        NSTextStorage* bodyText = [[NSTextStorage alloc] initWithAttributedString: bodyString];
        
        [[messageBodyView layoutManager] replaceTextStorage: bodyText];
        [bodyText release];
    }
}

- (IBAction) toggleDisplay: (id) sender
{
    // toggle:
    [tabView selectTabViewItemAtIndex: 1-[tabView indexOfTabViewItem: [tabView selectedTabViewItem]]];
}

- (IBAction) openSelection: (id) sender
{
    G3Message* message = nil;
    [self setDisplayedMessage: message];
    [tabView selectTabViewItemWithIdentifier: @"message"];
}

- (int) numberOfRowsInTableView: (NSTableView*) aTableView
{
    NSLog(@"%@ Group: %@", self, group);
    return [[group threads] count];
}


@end
