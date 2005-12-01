//
//  GIActivityPanelController.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 05.06.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <AppKit/AppKit.h>

@interface GIActivityPanelController : NSObject 
{
    IBOutlet NSWindow* window;
    IBOutlet NSTableView* tableView;
    
    NSArray* jobIds;
}

+ (void) showActivityPanelInteractive: (BOOL) interactive;
+ (void) updateData;

- (NSWindow*) window;

@end
