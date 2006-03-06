//
//  GIGroupWindow.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 03.12.04.
//  Copyright 2004 Objectpark. All rights reserved.
//

#import "GIGroupWindow.h"
#import <Foundation/NSDebug.h>
#import "GITextView.h"

/*" Informal protocol for ESCListerners "*/
@protocol ESCListener

- (void) switchKeyPressed:(id)sender;

@end

@implementation GIGroupWindow
/*" Window for message groups. Special behavior. At this time, the 'switch key' is intercepted. "*/

#define SWITCHKEY 0x24
#define ALTSWITCHKEY 0x4c
#define LEFTARROWKEY 0x7b
#define RIGHTARROWKEY 0x7c
#define DOWNARROWKEY 0x7d
#define UPARROWKEY 0x7e
#define TABKEY 0x30
#define SPACEKEY 0x31
#define KEYPAD0KEY  0x52
#define KEYPAD2KEY  0x54
#define KEYPAD4KEY  0x56
#define KEYPAD5KEY  0x57
#define KEYPAD6KEY  0x58
#define KEYPAD8KEY  0x5B
#define BACKSPACEKEY 0x33
#define ESCKEY 0x35

- (void)dealloc
{
    if (NSDebugEnabled) NSLog(@"GIGroupWindow dealloc");
    [super dealloc];
}

- (BOOL)makeFirstResponder:(NSResponder *)aResponder
{
    BOOL result = [super makeFirstResponder:aResponder];
//    NSLog(@"New first responder of %@ is %@ (success: %d)", self, [self firstResponder], result);
    return result;
}

- (void)sendActionSelector:(SEL)selector
{
    id delegate = [self delegate];
    if ([delegate respondsToSelector:selector]) 
    {
        //if ([delegate validateKeyboardSelector: selector]) {
        [delegate performSelector: selector withObject:self];
        //}
    } 
}

- (void)delegateAction:(SEL)selector
{
    id delegate = [self delegate];
    if ([delegate respondsToSelector:selector]) 
    {
        [delegate performSelector:selector withObject:self];
    }
}

- (void)sendEvent:(NSEvent *)theEvent
/*" Intercept the 'switch key' and inform the delegate and don't send the event further along the responder chain if it has a selector -switchKeyPressed:(id)sender. Otherwise the event is send further along the responder chain. "*/ 
{
    BOOL consumed = NO;
    
    if (![[self firstResponder] isKindOfClass: [NSSearchField class]]) 
    {
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
				case BACKSPACEKEY: {
						if (([theEvent modifierFlags] & NSCommandKeyMask) == 0) 
                        {
							if ((![[self firstResponder] isKindOfClass:[NSTextView class]])
								|| [[self firstResponder] isKindOfClass:[GITextView class]]) 
                            {
								[self sendActionSelector:@selector(closeSelection:)];
								return;
							}
						}
					}
                    break;
                case 2: // d
                case KEYPAD6KEY:
                case 42: // #
                    consumed = [[self delegate] messageShownCurrently];
                    [self delegateAction:@selector(navigateRightInMatrix:)];
                    break;
                    
                case 0: // a
                case 41: // Ö
                case KEYPAD4KEY:
                    consumed = [[self delegate] messageShownCurrently];
                    [self delegateAction:@selector(navigateLeftInMatrix:)];
                    break;
                    
                case 13: // w
                case 33: // Ü
                case KEYPAD8KEY:
                    consumed = [[self delegate] messageShownCurrently];
                    [self delegateAction:@selector(navigateUpInMatrix:)];
                    break;
                    
                case 1: // s
                case 39: // Ä
                case KEYPAD2KEY:
                case KEYPAD5KEY:
                    consumed = [[self delegate] messageShownCurrently];
                    [self delegateAction:@selector(navigateDownInMatrix:)];
                    break;
                    
				case SPACEKEY:
                    if (! [[self delegate] searchHitsShownCurrently]) {
                        [self delegateAction:@selector(showNextMessage:)];
                        consumed = YES;

                        theEvent = [NSApp nextEventMatchingMask:NSKeyUpMask
                                                      untilDate:[NSDate dateWithTimeIntervalSinceNow:2.0]
                                                         inMode:NSEventTrackingRunLoopMode
                                                        dequeue:YES];
                        
                        [NSApp discardEventsMatchingMask:NSAnyEventMask beforeEvent:theEvent];
					}
                    break;
					
                default:
					//NSLog(@"Key pressed. Code: %X", [theEvent keyCode]);
                    break;
            }        
        }
    }
    if (!consumed) [super sendEvent:theEvent];
}

@end

