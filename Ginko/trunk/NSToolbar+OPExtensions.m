//
//  NSToolbar+OPExtensions.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 21.12.04.
//  Copyright 2004 Objectpark. All rights reserved.
//

#import "NSToolbar+OPExtensions.h"
#import "NSArray+Extensions.h"

@implementation NSToolbar (OPExtensions)
/*" Extension of NSToolbar for utilizing a plist as definition for toolbars instead of code. For the plist format just look at the .toolbar resource files which are likely part of this project. "*/

- (BOOL)toolbarItems:(NSArray **)items defaultIdentifiers:(NSArray **)defaultIds forToolbarNamed: (NSString*) toolbarName
/*" Fetches toolbar items and default identifiers from a plist definition. items and defaultIds are not retained. Localization is performed on user visible texts. "*/
{
    NSToolbarItem *item;
    NSString *resourcePath;
    NSDictionary *toolbarDefinitons;
    NSEnumerator *enumerator;
    id itemIdentifier;
    
    // create dictionary of NSToolbarItems
    *items = [NSMutableArray array];
    
    // get path for preferences definitions
    resourcePath = [[NSBundle mainBundle] pathForResource:toolbarName ofType: @"toolbar"];
    if (! resourcePath) 
    {
        return NO;
    }
    
    // get dictionary with preferences definitions
    toolbarDefinitons = [NSDictionary dictionaryWithContentsOfFile:resourcePath];
    if (! toolbarDefinitons) 
    {
        return NO;
    }
    
    // get default items out of dictionary
    *defaultIds = [toolbarDefinitons objectForKey: @"toolbarDefaultItems"];
    if (! *defaultIds) 
    {
        return NO;
    }
    
    enumerator = [toolbarDefinitons keyEnumerator];
    while (itemIdentifier = [enumerator nextObject]) 
    {
        id itemDefs = [toolbarDefinitons objectForKey:itemIdentifier];
        if ([itemDefs isKindOfClass:[NSDictionary class]]) 
        {
            id target = nil;
            
            // add toolbar item
            item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
            [item setLabel:NSLocalizedString([itemDefs objectForKey: @"label"], @"toolbar label")];
            [item setPaletteLabel:NSLocalizedString([itemDefs objectForKey: @"paletteLabel"], @"toolbar palette label")];
            [item setToolTip:NSLocalizedString([itemDefs objectForKey: @"toolTip"], @"toolbar tooltip")];
            [item setAction:NSSelectorFromString([itemDefs objectForKey: @"action"])];
            [item setImage:[NSImage imageNamed:[itemDefs objectForKey: @"imageName"]]];
            [item setTarget:target];
            [(NSMutableArray *)*items addObject:item];
            [item release];
        }
    }
    
    *items = [*items sortedArrayByComparingAttribute: @"paletteLabel"];
    
    return YES;
}

+ (NSToolbarItem *)toolbarItemForItemIdentifier: (NSString*) itemIdentifier fromToolbarItemArray:(NSArray*) items
/*" Support for the corresponding toolbar delegate method. "*/
{
    NSEnumerator *enumerator;
    NSToolbarItem *item;
    
    enumerator = [items objectEnumerator];
    while(item = [enumerator nextObject])
    {
	if([[item itemIdentifier] isEqualToString:itemIdentifier])
        {
	    return item;
        }
    }
    return nil;
}

@end
