//
//  GIGroupListController.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 24.10.05.
//  Copyright 2005 Objectpark Group. All rights reserved.
//

#import <Cocoa/Cocoa.h> 
@class GIMessageGroup;
@class GIOutlineViewWithKeyboardSupport;

@interface GIGroupListController : NSObject 
{	
    IBOutlet GIOutlineViewWithKeyboardSupport *boxesView;
    IBOutlet NSWindow *window;
	IBOutlet NSProgressIndicator *globalProgrssIndicator;
}

+ (void)showGroup:(GIMessageGroup *)group reuseWindow:(BOOL)shouldReuse;

- (IBAction)addFolder:(id)sender;
- (IBAction)rename:(id)sender;
- (IBAction)exportGroup:(id)sender;
- (IBAction)addMessageGroup:(id)sender;
- (IBAction)removeFolderMessageGroup:(id)sender;
- (IBAction)delete:(id)sender;

@end
