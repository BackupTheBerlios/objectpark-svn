//
//  G3MessageEditorWindow.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 16.12.04.
//  Copyright 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "G3MessageEditorWindow.h"


@implementation G3MessageEditorWindow
/*" Window for message editors. Special behavior. "*/

#define TABKEY 0x30

- (void) sendEvent: (NSEvent*) theEvent
{
    if ([theEvent type] == NSKeyDown) {
        switch ([theEvent keyCode]) {
            case TABKEY:
                if ([[self delegate] respondsToSelector:@selector(tabKeyPressed:withmodifierFlags:)]) {
                    if ([[self delegate] performSelector:@selector(tabKeyPressed:withmodifierFlags:)
                                              withObject:self withObject:[NSNumber numberWithUnsignedInt:[theEvent modifierFlags]]]) {
                        return; // consume event
                    }
                }
                break;
            default:
                break;
        }        
    }
    
    [super sendEvent:theEvent];
}

@end
