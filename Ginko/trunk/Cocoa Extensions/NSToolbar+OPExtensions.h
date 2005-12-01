//
//  NSToolbar+OPExtensions.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 21.12.04.
//  Copyright 2004 Objectpark. All rights reserved.
//

#import <AppKit/AppKit.h>


@interface NSToolbar (OPExtensions)

- (BOOL)toolbarItems:(NSArray**) items defaultIdentifiers:(NSArray**) defaultIds forToolbarNamed: (NSString*) toolbarName;

+ (NSToolbarItem *)toolbarItemForItemIdentifier: (NSString*) itemIdentifier fromToolbarItemArray:(NSArray*) items;

@end
