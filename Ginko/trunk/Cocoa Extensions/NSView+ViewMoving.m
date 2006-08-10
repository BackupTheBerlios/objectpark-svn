//
//  NSView+ViewMoving.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 10.12.04.
//  Copyright 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "NSView+ViewMoving.h"


@implementation NSView (ViewMoving)

- (void)moveSubviewsWithinHeight:(float)height verticallyBy:(float)diff
{
    BOOL didMove = NO;
    NSEnumerator *e = [[self subviews] objectEnumerator];
    NSView *subview;
    
    while (subview = [e nextObject]) 
    {
        NSRect frame = [subview frame];
        
        if (frame.origin.y <= height) 
        {
            if ([subview autoresizingMask] & NSViewHeightSizable) 
            {
                // size height
                frame.size.height+=diff;
            } 
            else 
            {
                frame.origin.y+=diff;
            }
            [subview setFrame:frame];
            didMove = YES;
        }
    }
    
    if (didMove) [self setNeedsDisplay: YES];
}

@end
