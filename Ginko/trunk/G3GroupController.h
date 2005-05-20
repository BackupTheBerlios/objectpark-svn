//
//  G3GroupController.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 03.12.04.
//  Copyright 2004 Objectpark. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "G3Message.h"
#import "GIOutlineViewWithKeyboardSupport.h"

@class OPCollapsingSplitView;
@class G3MessageGroup;

@interface G3GroupController : NSObject 
{
    IBOutlet NSWindow *window;
    IBOutlet GIOutlineViewWithKeyboardSupport *threadsView;
    IBOutlet NSTabView *tabView;
    IBOutlet NSTextView *messageTextView;
    IBOutlet NSMatrix *commentsMatrix;
    IBOutlet NSTextField *groupInfoTextField;
    IBOutlet NSDrawer *boxesDrawer;
    IBOutlet NSOutlineView *boxesView;
    IBOutlet OPCollapsingSplitView *treeBodySplitter;
	
    NSArray* allGroups;
    G3MessageGroup *group;
    G3Thread *displayedThread; // displayed as comment tree
    G3Message *displayedMessage; // displayed with body
	NSArray *threadCache;
    
    // -- Toolbar --
    NSArray *toolbarItems;
    NSArray *defaultIdentifiers;
    
    // -- Comment Tree --
}

- (id)initWithGroup:(G3MessageGroup *)aGroup;
- (id)initAsStandAloneBoxesWindow:(G3MessageGroup *)aGroup;

- (NSWindow *)window;
- (G3MessageGroup *)group;
- (void)setGroup:(G3MessageGroup *)aGroup;
- (NSArray *)allGroups;

- (BOOL)isStandaloneBoxesWindow;

- (id)valueForGroupProperty:(NSString *)prop;
- (void)setValue:(id)value forGroupProperty:(NSString *)prop;

- (void)setDisplayedMessage:(G3Message *)aMessage thread:(G3Thread *)aThread;
- (G3Message *)displayedMessage;
- (G3Thread *)displayedThread;

- (BOOL)threadsShownCurrently;

- (BOOL)validateSelector:(SEL)aSelector; // necessary?

/*" Actions "*/
- (IBAction)showThreads:(id)sender;

- (IBAction)addFolder:(id)sender;
- (IBAction)rename:(id)sender;
- (IBAction)addMessageGroup:(id)sender;
- (IBAction)removeFolderMessageGroup:(id)sender;

@end

@interface G3GroupController (ToolbarDelegate)

- (void)awakeToolbar;
- (void)deallocToolbar;

@end
