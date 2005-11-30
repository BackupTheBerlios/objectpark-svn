//
//  GIGroupInspectorController.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 07.03.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "GIGroupInspectorController.h"
#import "GIProfile.h"

@implementation GIGroupInspectorController

static GIGroupInspectorController *sharedInspector = nil;

- (void) setupProfilePopUpButton
{
    NSEnumerator *enumerator;
    GIProfile *aProfile;
    
    [profileButton removeAllItems];
    
    // fill profiles in:
    enumerator = [GIProfile allObjectsEnumerator];
    while ((aProfile = [enumerator nextObject])) {
        [profileButton addItemWithTitle: [aProfile valueForKey: @"name"]];
        [[profileButton lastItem] setRepresentedObject: aProfile];
    }
}

- (void) setGroup: (GIMessageGroup*) aGroup
{
    [group autorelease];
    group = [aGroup retain];
    
    [self setupProfilePopUpButton];
    [profileButton selectItemAtIndex:[profileButton indexOfItemWithRepresentedObject:[aGroup defaultProfile]]];
    
    [window makeKeyAndOrderFront:self];
}

+ (id)groupInspectorForGroup: (GIMessageGroup*) aGroup
{
    if (! sharedInspector)
    {
        sharedInspector = [[self alloc] init];
    }
    
    [sharedInspector setGroup:aGroup];
    
    return sharedInspector;
}

- (id) init
{
    if ((self = [super init]))
    {
        NSLog(@"GIGroupInspectorController init");
        [NSBundle loadNibNamed: @"GroupInspector" owner:self];
    }
    
    return self;
}

- (void) awakeFromNib
{
}

- (IBAction) switchProfile: (id) sender
    /*" Triggered by the profile select popup. "*/
{
    GIProfile *newProfile;
    
    newProfile = [[profileButton selectedItem] representedObject];
    if ([group defaultProfile] != newProfile) // check if something to do
    {
        [group setDefaultProfile:newProfile];
    }
}

@end
