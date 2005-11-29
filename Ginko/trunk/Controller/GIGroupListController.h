//
//  GIGroupListController.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 24.10.05.
//  Copyright 2005 Objectpark Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface GIGroupListController : NSObject {
	
    IBOutlet NSOutlineView* boxesView;
    IBOutlet NSProgressIndicator* progressIndicator;
    IBOutlet NSWindow* window;
}

- (IBAction) addFolder: (id) sender;
- (IBAction) rename: (id) sender;
- (IBAction) addMessageGroup: (id) sender;
- (IBAction) removeFolderMessageGroup: (id) sender;
- (IBAction) delete: (id) sender;

@end
