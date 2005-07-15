//
//  GIActivityPanelController.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 05.06.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <AppKit/AppKit.h>

@interface GIActivityPanelController : NSObject 
{
    IBOutlet NSWindow *window;
    IBOutlet NSTableView *tableView;
    
    NSArray *jobIds;
}

+ (void) showActivityPanelInteractive: (BOOL) interactive;

- (NSWindow *)window;

@end
