//
//  GISearchController.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 04.06.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface GISearchController : NSObject {

    IBOutlet NSWindow*            searchWindow;
    IBOutlet NSSearchField*       searchField;
    IBOutlet NSTableView*         searchResultTableView;
    IBOutlet NSProgressIndicator* searchProgress;
    
    @private
    NSArray* searchResults;
}

- (IBAction) search: (id) sender;

- (NSWindow*) window;


@end
