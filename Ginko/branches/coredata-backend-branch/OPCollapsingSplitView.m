//
//  OPCollapsingSplitView.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 31.12.04.
//  Copyright 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "OPCollapsingSplitView.h"


@implementation OPCollapsingSplitView

//- (id)

/*
- initWithFrame: (NSRect) frameRect
{
    if (self = [super initWithFrame: frameRect]) {
        collapsedSubviewIndex = NSNotFound;
    }
    return self;
}

- initWithCoder: (NSCoder*) coder
{
    if (self = [super initWithCoder:coder]) {
        collapsedSubviewIndex = NSNotFound;
    }
    return self;
}
*/

- (void) setSubview: (NSView*) subview isCollapsed: (BOOL) collapse
/*" Collapses the subview specified. Only one subview can be collapsed.
    Needs work to function with vertical splitting. "*/
{
    if (subview) {
        NSSize frameSize = [subview frame].size;
        NSView* collapsedSubview = [self collapsedSubview];
        if (collapse) {
            // We shall collapose subview:
            if (subview != collapsedSubview) {
                // Uncollapse old subview:
                [self setSubview: collapsedSubview isCollapsed: NO];
                
                preservedSubviewSize = frameSize.height;
                [subview setFrameSize: NSMakeSize(frameSize.width, 0.0)];
            }
        } else {
            // We shall uncollapose subview:
            if (subview == collapsedSubview) {
                // restore preserved size:
                [subview setFrameSize: NSMakeSize(frameSize.width, preservedSubviewSize)];
            }
        }
    }
}

- (NSView*) collapsedSubview
{
    NSArray* subviews = [self subviews];
    int i = 0;
    int imax = [subviews count];
    while (i<imax) {
        NSView* view = [subviews objectAtIndex: i];
        if ([self isSubviewCollapsed: view]) {
            return view;
        }
    }
    return nil;
}

- (BOOL) isSubviewCollapsed: (NSView*) subview
{
    //int subViewIndex = [[self subviews] indexOfObject: subview];
    BOOL result = [super isSubviewCollapsed: subview];
    NSSize subviewSize = [subview frame].size;
    return result || ([self isVertical] ? subviewSize.width : subviewSize.height)<1.0;
}

- (void) moveSplitterBy: (float) moveValue
{
    NSLog(@"Will move splitter by %f", moveValue);
    if (moveValue!=0.0) {
        NSView* firstView = [[self subviews] objectAtIndex: 0];
        NSSize  firstViewSize = [firstView frame].size;
        NSView* lastView = [[self subviews] lastObject];
        NSRect  lastViewFrame = [lastView frame];

        [firstView setFrameSize: NSMakeSize(firstViewSize.width, firstViewSize.height+moveValue)];
        [lastView setFrame: NSMakeRect(lastViewFrame.origin.x, lastViewFrame.origin.y+moveValue, lastViewFrame.size.width, lastViewFrame.size.height-moveValue)];
        [self adjustSubviews];
    }
}

- (void) setFirstSubviewSize: (float) firstSize
{
    NSSize totalSize = [self frame].size;
    NSScrollView* firstView = [[self subviews] objectAtIndex: 0];
    NSSize  firstViewSize = [firstView frame].size;
    NSScrollView* lastView = [[self subviews] lastObject];    
    if ([self isVertical]) {
        firstViewSize.width = firstSize;
    } else {
        firstViewSize.height = firstSize;
    }
    [firstView setFrameSize: firstViewSize];
    [lastView setFrameSize: NSMakeSize(totalSize.width, totalSize.height-[self dividerThickness]-firstViewSize.height)]; 
    [self adjustSubviews];
}


@end
