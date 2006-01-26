//
//  GIThreadListController.h
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

@interface GIThreadListController : NSObject 
{
    IBOutlet NSWindow *window;
    IBOutlet GIOutlineViewWithKeyboardSupport *threadsView;
    IBOutlet NSTabView *tabView;
    IBOutlet NSTextView *messageTextView;
    IBOutlet NSMatrix *commentsMatrix;
    IBOutlet NSTextField *groupInfoTextField;
    IBOutlet OPCollapsingSplitView *treeBodySplitter;
    IBOutlet NSPopUpButton *threadFilterPopUp;
    IBOutlet NSProgressIndicator *progressIndicator;
    IBOutlet NSTableView *searchHitsTableView;
    IBOutlet NSSearchField *searchField;
    
    GIMessageGroup *group;
    GIThread *displayedThread; // displayed as comment tree
    GIMessage *displayedMessage; // displayed with body
    BOOL showRawSource;
    NSTimeInterval nowForThreadFiltering;

	BOOL isAutoReloadEnabled;
	
    NSMutableSet *itemRetainer;
    
    // -- Toolbar --
    NSArray *toolbarItems;
    NSArray *defaultIdentifiers;
    
    // -- Searching --
    NSArray *hits;
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
- (IBAction) threadFilterPopUpChanged: (id) sender;
- (IBAction) selectThreadsWithCurrentSubject: (id) sender;
- (IBAction) search: (id) sender;

@end

@interface GIThreadListController (ToolbarDelegate)

- (void) awakeToolbar;
- (void) deallocToolbar;

@end
