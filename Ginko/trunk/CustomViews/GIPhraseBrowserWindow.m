//
//  GIPhraseBrowserWindow.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 16.11.05.
//  Copyright 2005 The Objectpark Group. All rights reserved.
//

#import "GIPhraseBrowserWindow.h"
#import "GIPhraseBrowserController.h"

@implementation GIPhraseBrowserWindow

- (void)sendEvent:(NSEvent *)theEvent
{
    if (([theEvent type] == NSKeyDown) && ([[self firstResponder] isKindOfClass:[NSTableView class]]))
    {
        switch ([[theEvent characters] characterAtIndex:0])
        {
            case '0':
                [[self delegate] hotkeyPressed:0];
                return;
            case '1':
                [[self delegate] hotkeyPressed:1];
                return;
            case '2':
                [[self delegate] hotkeyPressed:2];
                return;
            case '3':
                [[self delegate] hotkeyPressed:3];
                return;
            case '4':
                [[self delegate] hotkeyPressed:4];
                return;
            case '5':
                [[self delegate] hotkeyPressed:5];
                return;
            case '6':
                [[self delegate] hotkeyPressed:6];
                return;
            case '7':
                [[self delegate] hotkeyPressed:7];
                return;
            case '8':
                [[self delegate] hotkeyPressed:8];
                return;
            case '9':
                [[self delegate] hotkeyPressed:9];
                return;
            default:
                break;
        }        
    }
    
    [super sendEvent:theEvent];
}

@end
