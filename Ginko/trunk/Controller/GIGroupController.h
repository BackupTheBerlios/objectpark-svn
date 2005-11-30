//
//  GIGroupController.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 03.12.04.
//  Copyright 2004 Objectpark Group. All rights reserved.
//

#import <AppKit/AppKit.h>

@class OPCollapsingSplitView;
@class GIMessageGroup;
@class GIOutlineViewWithKeyboardSupport;
@class GIMessage;
@class GIThread;

@interface GIGroupController : NSObject 
{
    IBOutlet NSWindow* window;
    IBOutlet GIOutlineViewWithKeyboardSupport* threadsView;
    IBOutlet NSTabView* tabView;
    IBOutlet NSTextView* messageTextView;
    IBOutlet NSMatrix* commentsMatrix;
    IBOutlet NSTextField* groupInfoTextField;
    IBOutlet NSDrawer* boxesDrawer;
    IBOutlet NSOutlineView* boxesView;
    IBOutlet OPCollapsingSplitView* treeBodySplitter;
    IBOutlet NSPopUpButton* threadFilterPopUp;
    IBOutlet NSProgressIndicator* progressIndicator;

    GIMessageGroup* group;
    GIThread* displayedThread; // displayed as comment tree
    GIMessage* displayedMessage; // displayed with body
    NSMutableArray* threadCache; // contains item uris
    NSMutableSet* nonExpandableItemsCache; // contains GIThreads
    BOOL showRawSource;
    NSTimeInterval nowForThreadFiltering;
    
    // -- Toolbar --
    NSArray* toolbarItems;
    NSArray* defaultIdentifiers;
    
    // -- Comment Tree --
}

- (id) initWithGroup: (GIMessageGroup*) aGroup;

+ (NSWindow*) windowForGroup: (GIMessageGroup*) aGroup;

- (NSWindow*) window;
- (GIMessageGroup*) group;
- (void) setGroup: (GIMessageGroup*) aGroup;


- (id)valueForGroupProperty: (NSString*) prop;
- (void) setValue:(id)value forGroupProperty: (NSString*) prop;

- (void) setDisplayedMessage: (GIMessage*) aMessage thread: (GIThread*) aThread;
- (GIMessage*) displayedMessage;
- (GIThread*) displayedThread;

- (BOOL) threadsShownCurrently;

- (BOOL) validateSelector: (SEL) aSelector; // necessary?

- (void) modelChanged: (NSNotification*) aNotification; // remove as soon as possible

/*" Actions "*/
- (IBAction) showThreads: (id) sender;
- (IBAction) addFolder: (id) sender;
- (IBAction) rename: (id) sender;
- (IBAction) addMessageGroup: (id) sender;
- (IBAction) removeFolderMessageGroup: (id) sender;
- (IBAction) threadFilterPopUpChanged: (id) sender;
- (IBAction) selectThreadsWithCurrentSubject: (id) sender;

@end

@interface GIGroupController (ToolbarDelegate)

- (void) awakeToolbar;
- (void) deallocToolbar;

@end
