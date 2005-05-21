//
//  Created by Dirk Theisen on Sat Feb 02 2002.
//  Copyright (c) 2001 Dirk Theisen. All rights reserved.
//
/*
 Permission to use, copy, modify and distribute this software and its documentation
 is hereby granted, provided that both the copyright notice and this permission
 notice appear in all copies of the software, derivative works or modified versions,
 and any portions thereof, and that both notices appear in supporting documentation,
 and that credit is given to Bjoern Bubbat in all documents and publicity
 pertaining to direct or indirect use of this code or its derivatives.

 THIS IS EXPERIMENTAL SOFTWARE AND IT IS KNOWN TO HAVE BUGS, SOME OF WHICH MAY HAVE
 SERIOUS CONSEQUENCES. THE COPYRIGHT HOLDER ALLOWS FREE USE OF THIS SOFTWARE IN ITS
 "AS IS" CONDITION. THE COPYRIGHT HOLDER DISCLAIMS ANY LIABILITY OF ANY KIND FOR ANY
 DAMAGES WHATSOEVER RESULTING DIRECTLY OR INDIRECTLY FROM THE USE OF THIS SOFTWARE
 OR OF ANY DERIVATIVE WORK.

 Further information can be found on the project's web pages
 at http://www.objectpark.org/
 */

#import "OPPreferenceController.h"
#import "OPPreferencePane.h"
#import <Foundation/NSDebug.h>
#import "NSApplicationOPPreferenceSupport.h"

@implementation OPPreferenceController

static OPPreferenceController *preferences = nil;

#import <objc/objc-runtime.h>
#import <objc/objc-class.h>

/*
// ED* functions used under licence from Eric Doernenburg:
static BOOL EDClassIsSuperclassOfClass(Class aClass, Class subClass)
{
    Class class;

    class = subClass->super_class;
    while(class != nil)
    {
        if(class == aClass)
            return YES;
        class = class->super_class;
    }
    return NO;
}

static NSArray *EDSubclassesOfClass(Class aClass) {
    NSMutableArray *subclasses;
    Class          *classes;
    int            numClasses, newNumClasses, i;

    // cf. /System/Library/Frameworks/System.framework/Headers/objc/objc-runtime.h
    numClasses = 0, newNumClasses = objc_getClassList(NULL, 0);
    classes = NULL;
    while (numClasses < newNumClasses)
    {
        numClasses = newNumClasses;
        classes = realloc(classes, sizeof(Class) * numClasses);
        newNumClasses = objc_getClassList(classes, numClasses);
    }

    subclasses = [NSMutableArray array];
    for(i = 0; i < numClasses; i++)
    {
        if(EDClassIsSuperclassOfClass(aClass, classes[i]) == YES)
            [subclasses addObject:classes[i]];
    }
    free(classes);

    return subclasses;
}

*/

+ (id) standardPreferences
{
    if (!preferences) {
        preferences = [[[self alloc] init] autorelease];
    }
    return preferences;
}

+ (void) showPreferencesWindow
{
    [[[self standardPreferences] window] makeKeyAndOrderFront: preferences];
}

+ (void) showPreferencesWindowWithPaneNamed: (NSString*) paneName
{
    [self showPreferencesWindow];
    [[self standardPreferences] switchToPaneNamed: paneName];
}

- (void) _storeWindowPosition
{
    NSRect frame = [_window frame];
    NSPoint topleft = NSMakePoint(frame.origin.x, frame.origin.y+frame.size.height);
    [[NSUserDefaults standardUserDefaults] setObject: NSStringFromPoint(topleft)
                                              forKey: @"OPPreferencesWindowPosition"];
}

- (void) _restoreWindowPosition {
    NSString* pos = [[NSUserDefaults standardUserDefaults] stringForKey: @"OPPreferencesWindowPosition"];
    if (pos) {
        NSPoint topleft = NSPointFromString(pos);
        NSRect oldFrame = [_window frame];
        NSRect frame = NSMakeRect(topleft.x, topleft.y-oldFrame.size.height, oldFrame.size.width, oldFrame.size.height);
        [_window setFrame: frame display: NO];
    }
}

- (id) init {
    if (self = [super init]) {
        preferencesPanes = [[NSMutableDictionary alloc] init];
        // Set preferences window manually. This is easy to do, faster than loading a
        // nib and easily portable to GNUstep.
        _window = [[NSWindow alloc] initWithContentRect: NSMakeRect(33,644,200,5)
                                              styleMask: NSTitledWindowMask |     NSClosableWindowMask | NSMiniaturizableWindowMask
                                                backing: NSBackingStoreBuffered
                                                  defer: YES];
        [_window setDelegate: self];
        [_window setReleasedWhenClosed: YES];
        [_window setTitle: @"Preferences"];
        toolbarIdentifiers = nil;

        [self _restoreWindowPosition];

        [self awakeFromNib];
    }
    return self;
}


- (void) setCurrentView:(NSView *)aView 
{
    [currentView autorelease];
    currentView = [aView retain];
}


- (void) setCurrentPane: (OPPreferencePane*) newPane 
{
    if (newPane!=currentPane) {
        [currentPane release];
        currentPane = [newPane retain];
    }
}



- (void) changeWindowSize: (NSView*) aView 
{
    NSRect currentFrame = [_window frame];
    NSRect viewFrame = [aView frame];
    int diff = (viewFrame.size.height+toolbarHeight) - currentFrame.size.height;

    currentFrame.size.height = viewFrame.size.height+toolbarHeight;
    currentFrame.size.width = MAX(viewFrame.size.width, currentFrame.size.width);
    currentFrame.origin.y -= diff;
    [_window setFrame: currentFrame display: YES animate: YES];
}


- (void) exchangeViewFromPane: (OPPreferencePane*) pane
{
    //NSLog(@"Loading %@.nib", [pane mainNibName]);
    NSView* newView = [pane loadMainView];
    
    NSRect newViewFrame = [newView frame];
    int xSizeWindow;
    int xSizeView;
    int xPosView;

    if (NSDebugEnabled) NSLog(@"Showing preference pane %@", pane);

    [currentView removeFromSuperview];

    [self changeWindowSize: newView];
    xSizeWindow = [_window frame].size.width;
    xSizeView = newViewFrame.size.width;
    xPosView = (xSizeWindow/2)-(xSizeView/2);
    if (xPosView < 0) {
        xPosView = 0;
    }
    newViewFrame.origin.x = xPosView;
    newViewFrame.origin.y = 0;
    [newView setFrame:newViewFrame];
    [self setCurrentView:newView];
    if (newView) {
        [[_window contentView] addSubview:newView];
    }
}

- (OPPreferencePane*) paneWithName: (NSString*) name
{
    OPPreferencePane* result = [preferencesPanes objectForKey: name];
    if (!result) {
        // try to load one:
        Class paneClass = NSClassFromString(name);
        if (paneClass) {
            result = [[[paneClass alloc] init] autorelease];
            if (NSDebugEnabled) NSLog(@"Created pane %@", result);
            // Cache the result object:
            [preferencesPanes setObject: result forKey: name];
        } else {
            NSLog(@"OPPreferences: Warning: Unable to load preferences pane class called '%@'", name);
        }
    }
    return result;
}


- (BOOL) validateToolbarItem: (NSToolbarItem*) theItem 
{
    // Make sure, the currently selected pane icon is disabled:
    return  !disableActiveItem || !(currentPane && [[theItem itemIdentifier] isEqualToString: NSStringFromClass([currentPane class])]);
}


/* Returns the toolbar image to be used. Searches for a tiff image named imageName in the main bundle, in the bundle of self and in the OPPreferences framework. If all fails, it returns a generic icon. */
- (NSImage*) toolbarImageForName: (NSString*) imageName
{
    NSString* path = [[NSBundle mainBundle] pathForImageResource: imageName];
        
    if (!path) {
        path = [[NSBundle bundleForClass: [self class]] pathForImageResource: imageName];
    }
    if (!path) {
        path = [[NSBundle bundleForClass: NSClassFromString(imageName)] pathForImageResource: imageName];
    }
    if (!path) {
        path = [[NSBundle bundleForClass: [self class]] pathForImageResource: @"OPDefaultPreference"];
    }
    return path ? [[[NSImage alloc] initWithContentsOfFile: path] autorelease] : nil;
}

-(NSArray*) toolbarItems
{
    if (!toolbarItems) {
        NSToolbarItem* item;
        int loop;
        NSArray* plist = [self itemIdentifiers];
        
        if (NSDebugEnabled) NSLog(@"Found the following (sorted) preference panes: %@", plist);

        // Create the array of toolbar items and the dictionary of OPPreferencePanes:
        toolbarItems = [[NSMutableArray alloc] init];

        for (loop=0; loop<[plist count]; loop++) {
            
            NSString*         itemIdentifier = [plist objectAtIndex: loop];
            NSString*         paneName       = NSLocalizedString(itemIdentifier, @"");

            NSImage* image = [self toolbarImageForName: itemIdentifier];

            // add toolbar item
            item = [[NSToolbarItem alloc] initWithItemIdentifier: itemIdentifier];
            [item setLabel: paneName];
            [item setPaletteLabel: paneName];
            //[item setToolTip: [pane tooltip]];
            [item setAction: @selector(showPreferencesView:)];
            [item setImage: image];
            [item setTarget: self];
            [toolbarItems addObject: item];
            [item release];
        }
        
        toolbarIdentifiers = [plist retain];
        
        
        
    }
    return toolbarItems;
}

-(void) addPrefPaneAtPath: (NSString*) path
{
    NSBundle*         bundle         = [NSBundle bundleWithPath: path];
    [bundle load];
    Class             paneClass      = [bundle principalClass];
    NSString*         itemIdentifier = NSStringFromClass(paneClass);
    NSPreferencePane* pane           = [[paneClass alloc] init];
    NSToolbarItem* item;


    if (NSDebugEnabled) NSLog(@"Created pane %@", pane);
    if (pane) {
        NSImage* image = [[[NSImage alloc] initWithContentsOfFile: [[NSBundle bundleForClass: [OPPreferencePane class]] pathForResource: @"OPDefaultPreference" ofType: @"tiff"]] autorelease];

        // add toolbar item
        item = [[NSToolbarItem alloc] initWithItemIdentifier: itemIdentifier];
        [item setLabel: itemIdentifier];
        [item setPaletteLabel: itemIdentifier];
        [item setAction: @selector(showPreferencesView:)];
        [item setImage: image];
        [item setTarget: self];
        [self toolbarItems];
        [toolbarItems addObject: item];
        [item release];

        if (NSDebugEnabled) NSLog(@"Created pane %@ with identifier %@.", pane, itemIdentifier);

        [pane release];
    }

}


- (void) switchToPane: (OPPreferencePane*) newPane
{
    if (NSDebugEnabled) NSLog(@"Switching to pane  %@", newPane);
    NSParameterAssert(newPane!=nil);
    [_window makeFirstResponder: _window];

    [currentPane willUnselect];
    [newPane willSelect];
    [self exchangeViewFromPane: newPane];
    [currentPane didUnselect];
    [self setCurrentPane: newPane];
    [newPane didSelect];
}


- (void) switchToPaneNamed: (NSString*) itemID
/*" Identifiers are the pane class names. I.e. passing "OPLicensePrefs" will work. "*/
{
    if (NSDebugEnabled) NSLog(@"Switching to pane called %@", itemID);
    NSParameterAssert([itemID length]>0);
    // toolbar item identifiers are the pane class names:
    if (!(currentPane && [NSStringFromClass([currentPane class]) isEqualToString: itemID])) {
        OPPreferencePane* newPane = [self paneWithName: itemID];
        [self switchToPane: newPane];
        //NSString* title = NSLocalizedStringFromTableInBundle(@"%@ Preferences", nil, [NSBundle bundleForClass: [self class]], @"window title format pattern");
        NSString* title = NSLocalizedString(@"%@ Preferences", @"window title format pattern");
        [_window setTitle: [NSString stringWithFormat: title, NSLocalizedString(itemID, @"")]];
    
    }
}

- (void) assureToolbarItemsVisible
{
    NSRect frame = [_window frame];
    NSToolbar* toolbar = [_window toolbar];
    while ([[toolbar visibleItems] count] < [[toolbar items] count]) {
        // Make window wider:
        frame.size.width+=16;
        [_window setFrame: frame display: NO];
    }
    [_window setFrame: frame display: YES];
}


- (void) awakeFromNib
{
    NSToolbar *toolbar;
    int windowHeight;

    [self retain];
    if (NSDebugEnabled) NSLog(@"Preferences awaking From nib.");
    windowHeight = [_window frame].size.height;

    toolbar = [[NSToolbar alloc] initWithIdentifier: @"GIPreferencesToolbar"];
    [toolbar setDelegate: self];
    [toolbar setAllowsUserCustomization: NO];
    [toolbar setAutosavesConfiguration: NO];
    [_window setToolbar: toolbar];
    toolbarHeight = [_window frame].size.height - windowHeight+20;

    // Show first preference panel from configuration:
    if ([[self toolbarItems] count]) {
        [self assureToolbarItemsVisible];
        
        [self switchToPaneNamed:[[toolbarItems objectAtIndex:0] itemIdentifier]];
        disableActiveItem = NO;
        if ([toolbar respondsToSelector:@selector(setSelectedItemIdentifier:)]) {
            [toolbar setSelectedItemIdentifier:[[toolbarItems objectAtIndex:0] itemIdentifier]];
        } else {
            disableActiveItem = YES;
        }
    }

    //#warning todo: Make window as broad as the first pane.
}

- (void) windowWillClose: (NSNotification*) aNotification {
    // We do this to catch the case where the user enters a value into one of the text fields but closes the window without hitting enter or tab.
    NSWindow *window = [aNotification object];
    (void)[window makeFirstResponder: window];

    [self _storeWindowPosition];
    [currentPane willUnselect];
    if (NSDebugEnabled) NSLog(@"Will close preferences window. Sync'ing user defaults...");
    [currentPane didUnselect];

    [[NSUserDefaults standardUserDefaults] synchronize];
    [self release];
}

/*
 This method is not called. Why not?
 - (void) windowDidClose: (NSNotification*) aNotification {
     [currentPane didUnselect];
     //if (NSDebugEnabled)
     NSLog(@"Did close preferences window. Sync'ing user defaults...");
     [[NSUserDefaults standardUserDefaults] synchronize];
     [self release];
 }
 */


-(NSWindow*) window 
{
    return _window;
}


-(IBAction) showPreferencesView: (id) sender {
    [self switchToPaneNamed: [sender itemIdentifier]];
}


- (NSToolbarItem*) toolbar: (NSToolbar*) toolbar itemForItemIdentifier: (NSString*) itemIdentifier willBeInsertedIntoToolbar: (BOOL) flag 
{
    NSEnumerator *enumerator;
    NSToolbarItem *item;

    enumerator = [[self toolbarItems] objectEnumerator];
    while(item = [enumerator nextObject]) {
        if([[item itemIdentifier] isEqualToString: itemIdentifier]) {
            return item;
        }
    }
    return nil;
}

- (NSArray*) itemIdentifiers
{
    if (!toolbarIdentifiers) {
        toolbarIdentifiers = [NSApp activePrefPanes];
    }
    return toolbarIdentifiers;
}

- (NSArray*) toolbarSelectableItemIdentifiers:(NSToolbar*) toolbar
{
    return [self itemIdentifiers];
}

- (NSArray*) toolbarDefaultItemIdentifiers: (NSToolbar*) toolbar 
{
    return [self itemIdentifiers];
}

- (NSArray*) toolbarAllowedItemIdentifiers: (NSToolbar*) toolbar 
{
    return [self itemIdentifiers];
}

- (void) dealloc 
{
    if (self==preferences) preferences = nil; // remove global instance
    [preferencesPanes release];
    [self setCurrentView: nil];
    [toolbarItems release];
    [self setCurrentPane: nil];
    [toolbarIdentifiers release];

    [super dealloc];
}


- (void)changeFont:(id)sender
/*" Forwards the changeFont: message to current pane.

    This is needed because the current pane is not in the regular responder chain. "*/
{
    if ([currentPane respondsToSelector:@selector(changeFont:)])
    {
        [(id)currentPane changeFont:sender];
    }
}

@end
