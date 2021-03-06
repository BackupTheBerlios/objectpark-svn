//
//  GISearchController.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 04.06.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
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

- (void) dealloc
{
    [cachedMessage release];
    [searchResults release];
    [super dealloc];
}

- (id) tableView: (NSTableView*) aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
    // Cache last message:
    NSString* messageId = [[self searchResults] objectAtIndex: rowIndex];
    if (![[cachedMessage messageId] isEqualToString: messageId]) {
        [cachedMessage release];
        cachedMessage = [[G3Message messageForMessageId: messageId] retain];
    }
    
    NSString* identifier = [aTableColumn identifier];
    if ([identifier isEqualToString: @"date"]) {
        return [cachedMessage valueForKey: @"date"];
    } 
    
    return [cachedMessage valueForKey: @"subject"];
}


@end
