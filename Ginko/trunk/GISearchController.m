//
//  GISearchController.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 04.06.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "GISearchController.h"
#import "GIFulltextIndexCenter.h"
#import "GIApplication.h"
#import "G3Message.h"


@implementation GISearchController

/*
- (void) awakeFromNib
{
  //  [GIApp setSearchController: self];   
}
*/

- (NSWindow*) window
{
    return searchWindow;
}

- (NSArray*) searchResults
{
    //NSLog(@"-[G3GroupController searchResults]");
    return searchResults;
}

- (void) setSearchResults: (NSArray*) newSearchResults
{
    NSLog(@"-[G3GroupController setSearchResults:(NSArray*)newSearchResults]");
    [newSearchResults retain];
    [searchResults release];
    searchResults = newSearchResults;
    [searchResultTableView reloadData];
}

- (IBAction)search:(id)sender
{
    NSLog(@"[G3GroupController search] will search for %@", [sender stringValue]);
    // set searchResults
    [self setSearchResults:[[GIFulltextIndexCenter defaultIndexCenter] hitsForQueryString:[sender stringValue]]];
}

- (int) numberOfRowsInTableView: (NSTableView*) aTableView
{
    return [[self searchResults] count];
}

- (id) tableView: (NSTableView*) aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
    // Cache last message:
    static G3Message* lastMessage = nil; // leaking one message. move to ivar
    NSString* messageId = [[self searchResults] objectAtIndex: rowIndex];
    if (![[lastMessage messageId] isEqualToString: messageId]) {
        [lastMessage release];
        lastMessage = [[G3Message messageForMessageId: messageId] retain];
    }
    
    NSString* identifier = [aTableColumn identifier];
    if ([identifier isEqualToString: @"date"]) {
        return [lastMessage valueForKey: @"date"];
    } 
    
    return [lastMessage valueForKey: @"subject"];
}


@end
