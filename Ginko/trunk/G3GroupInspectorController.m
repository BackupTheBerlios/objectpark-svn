//
//  G3GroupInspectorController.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 07.03.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "G3GroupInspectorController.h"
#import "G3Profile.h"

@implementation G3GroupInspectorController

static G3GroupInspectorController *sharedInspector = nil;

- (void)setupProfilePopUpButton
{
    NSEnumerator *enumerator;
    G3Profile *aProfile;
    
    [profileButton removeAllItems];
    
    // fill profiles in:
    enumerator = [[G3Profile profiles] objectEnumerator];
    while ((aProfile = [enumerator nextObject]))
    {
        [profileButton addItemWithTitle:[aProfile primitiveValueForKey:@"name"]];
        [[profileButton lastItem] setRepresentedObject:aProfile];
    }
}

- (void)setGroup:(G3MessageGroup *)aGroup
{
    [group autorelease];
    group = [aGroup retain];
    
    [self setupProfilePopUpButton];
    [profileButton selectItemAtIndex:[profileButton indexOfItemWithRepresentedObject:[aGroup defaultProfile]]];
    
    [window makeKeyAndOrderFront:self];
}

+ (id)groupInspectorForGroup:(G3MessageGroup *)aGroup
{
    if (! sharedInspector)
    {
        sharedInspector = [[self alloc] init];
    }
    
    [sharedInspector setGroup:aGroup];
    
    return sharedInspector;
}

- (id)init
{
    if ((self = [super init]))
    {
        NSLog(@"G3GroupInspectorController init");
        [NSBundle loadNibNamed:@"GroupInspector" owner:self];
    }
    
    return self;
}

- (void)awakeFromNib
{
}

- (IBAction)switchProfile:(id)sender
    /*" Triggered by the profile select popup. "*/
{
    G3Profile *newProfile;
    
    newProfile = [[profileButton selectedItem] representedObject];
    if ([group defaultProfile] != newProfile) // check if something to do
    {
        [group setDefaultProfile:newProfile];
    }
}

@end
