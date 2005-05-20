//
//  G3GroupWindow.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 03.12.04.
//  Copyright 2004 Objectpark. All rights reserved.
//

#import "G3GroupWindow.h"
#import <Foundation/NSDebug.h>

/*" Informal protocol for ESCListerners "*/
@protocol ESCListener

- (void)switchKeyPressed:(id)sender;

@end

@implementation G3GroupWindow
/*" Window for message groups. Special behavior. At this time, the 'switch key' is intercepted. "*/

#define SWITCHKEY 0x24
#define ALTSWITCHKEY 0x4c
#define LEFTARROWKEY 0x7b
#define RIGHTARROWKEY 0x7c
#define DOWNARROWKEY 0x7d
#define UPARROWKEY 0x7e
#define TABKEY 0x30
#define KEYPAD0KEY  0x52
#define KEYPAD2KEY  0x54
#define KEYPAD4KEY  0x56
#define KEYPAD5KEY  0x57
#define KEYPAD6KEY  0x58
#define KEYPAD8KEY  0x5B
#define BACKSPACEKEY 0x33
#define ESCKEY 0x35

- (void) dealloc
{
    if (NSDebugEnabled) NSLog(@"G3GroupWindow dealloc");
    [super dealloc];
}

- (BOOL) makeFirstResponder: (NSResponder*) aResponder
{
    BOOL result = [super makeFirstResponder: aResponder];
//    NSLog(@"New first responder of %@ is %@ (success: %d)", self, [self firstResponder], result);
    return result;
}


- (void) sendActionSelector: (SEL) selector
{
    id delegate = [self delegate];
    if ([delegate respondsToSelector: selector]) {
        //if ([delegate validateKeyboardSelector: selector]) {
        [delegate performSelector: selector withObject: self
            ];
        //}
    } 
}

- (void) sendEvent: (NSEvent*) theEvent
/*" Intercept the 'switch key' and inform the delegate and don't send the event further along the responder chain if it has a selector -switchKeyPressed:(id)sender. Otherwise the event is send further along the responder chain. "*/ 
{
    BOOL consumed = NO;
    if ([theEvent type] == NSKeyDown)
    {
        switch ([theEvent keyCode])
        {
            case SWITCHKEY:
            case ALTSWITCHKEY:
                [self sendActionSelector: @selector(openSelection:)];
                return;
                break;
            //case TABKEY:
            //    [self sendActionSelector: @selector(tabKeyPressed:withmodifierFlags:)];
            //    break;
            case ESCKEY:
            case BACKSPACEKEY:
                [self sendActionSelector: @selector(closeSelection:)];
                return;
                break;
            
            /*
            case LEFTARROWKEY:
            case KEYPAD4KEY:
                consumed = [self sendActionSelector:@selector(navigateLeft:)];
                break;
            case KEYPAD6KEY:
            case RIGHTARROWKEY:
                consumed = [self sendActionSelector:@selector(navigateRight:)];
                break;    
                
            case UPARROWKEY:
            case KEYPAD8KEY:
                consumed = [self sendActionSelector:@selector(navigateUp:)];
                break;            
            case DOWNARROWKEY:
            case KEYPAD2KEY:
                consumed = [self sendActionSelector:@selector(navigateDown:)];
                break; 
                */
                   
            default:
//                NSLog(@"Key pressed. Code: %X", [theEvent keyCode]);
                break;
        }        
    }
    
    if (!consumed) [super sendEvent:theEvent];
}

@end

