//
//  GISearchController.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 04.06.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <AppKit/AppKit.h>
@class G3Message;

@interface GISearchController : NSObject {

    IBOutlet NSWindow*            searchWindow;
    IBOutlet NSSearchField*       searchField;
    IBOutlet NSTableView*         searchResultTableView;
    IBOutlet NSProgressIndicator* searchProgress;
    
    @private
    NSArray* searchResults;
    G3Message* cachedMessage; // used only in tableViewDataSource
}

- (IBAction) search: (id) sender;

- (NSWindow*) window;


@end
