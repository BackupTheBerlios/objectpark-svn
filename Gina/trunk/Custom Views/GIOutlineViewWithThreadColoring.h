//
//  GIOutlineViewWithThreadColoring.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 22.10.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface GIOutlineViewWithThreadColoring : NSOutlineView 
{
    BOOL highlightThreads;
}

- (BOOL)highlightThreads;
- (void)setHighlightThreads:(BOOL)aBool;

@end
