//
//  G3MessageTextView.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 17.12.04.
//  Copyright 2004 __MyCompanyName__. All rights reserved.
//

#import "G3MessageTextView.h"

#define TABKEY 0x30

@implementation G3MessageTextView

- (void)keyDown:(NSEvent *)theEvent
{
    if ([theEvent keyCode] == TABKEY)
    {
        if ([[self delegate] respondsToSelector:@selector(tabKeyPressed:withmodifierFlags:)])
        {
            if ([[self delegate] performSelector:@selector(tabKeyPressed:withmodifierFlags:)
                                      withObject:self withObject:[NSNumber numberWithUnsignedInt:[theEvent modifierFlags]]])
            {
                return; // consume event
            }
        }
    }
    
    [super keyDown:theEvent];
}

@end
