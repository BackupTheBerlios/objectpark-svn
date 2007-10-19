//
//  GIMainWindowController.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 12.10.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GICommentTreeView.h"

@interface GIMainWindowController : NSWindowController 
{
	IBOutlet NSTreeController *messageGroupTreeController;
	IBOutlet NSTreeController *threadTreeController;
	IBOutlet GICommentTreeView *commentTreeView;
}

- (IBAction)commentTreeSelectionChanged:(id)sender;

@end
