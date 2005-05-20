//
//  OPCollapsingSplitView.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 31.12.04.
//  Copyright 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "OPCollapsingSplitView.h"


@implementation OPCollapsingSplitView

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


- (void) setSubview: (NSView*) subview isCollapsed: (BOOL) collapse
/*" Collapses the subview specified. Only one subview can be collapsed.
    Needs work to function with vertical splitting. "*/
{
    unsigned subViewIndex = [[self subviews] indexOfObject: subview];
    NSSize frameSize = [subview frame].size;

    if (collapse) {
        if (subViewIndex!=collapsedSubviewIndex) {
            if (collapsedSubviewIndex!=NSNotFound) 
                [self setSubview: [[self subviews] objectAtIndex: collapsedSubviewIndex] 
                     isCollapsed: NO];
            
            collapsedSubviewIndex = subViewIndex;
            preservedSubviewSize = frameSize.height;
            [subview setFrameSize: NSMakeSize(frameSize.width, 0.0)];
        }
    } else {
        if (subViewIndex == subViewIndex) {
            if (collapsedSubviewIndex!=NSNotFound) {
                // uncollapse collapsedSubviewIndex:
                [subview setFrameSize: NSMakeSize(frameSize.width, preservedSubviewSize)];
                collapsedSubviewIndex = NSNotFound;
            }
        }
    }
}

- (BOOL) isSubviewCollapsed: (NSView*) subview
{
    collapsedSubviewIndex=0;
    int subViewIndex = [[self subviews] indexOfObject: subview];
    return subViewIndex==collapsedSubviewIndex || [super isSubviewCollapsed: subview];
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
    firstViewSize.height = firstSize;
    [firstView setFrameSize: firstViewSize];
    [lastView setFrameSize: NSMakeSize(totalSize.width, totalSize.height-[self dividerThickness]-firstViewSize.height)]; 
    [self adjustSubviews];
}


@end
