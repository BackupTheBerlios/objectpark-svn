//
//  GIMatrixWithKeyboardSupport.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 13.01.05.
//  Copyright 2005 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "GIMatrixWithKeyboardSupport.h"

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

@implementation GIMatrixWithKeyboardSupport

- (id) initWithFrame: (NSRect) frame 
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

/*
- (void)drawRect:(NSRect)rect {
    // Drawing code here.
}
*/

- (BOOL) acceptsFirstResponder
{
    return YES;
}

- (NSFocusRingType) focusRingType
{
    return NSFocusRingTypeExterior;
}

- (BOOL) becomeFirstResponder
{
    NSLog(@"Matrix now first responder!");
    [[self superview] setFocusRingType: NSFocusRingTypeExterior];
    return [super becomeFirstResponder];
}

- (BOOL) resignFirstResponder
{
    NSLog(@"Matrix no longer first responder!");
    return [super resignFirstResponder];
}

- (void) mouseDown: (NSEvent*) theEvent 
{
    [super mouseDown: theEvent];
    [[self window] makeFirstResponder: self];
}

- (void) delegateAction: (SEL) selector
{
    id delegate = [self delegate];
    if ([delegate respondsToSelector: selector]) {
        [delegate performSelector: selector withObject: self];
    }
}

- (void) keyDown: (NSEvent*) theEvent 
/*" Sends navigateRightInMatrix: etc. to the delegate to indicate that the selection should be moved as response to a keyboard action (e.g. arrow keys). "*/
{
    switch ([theEvent keyCode]) 
    {        
        case KEYPAD6KEY:
        case RIGHTARROWKEY:
            [self delegateAction: @selector(navigateRightInMatrix:)];
            break;
            
        case LEFTARROWKEY:
        case KEYPAD4KEY:
            [self delegateAction: @selector(navigateLeftInMatrix:)];
            break;
            
        case UPARROWKEY:
        case KEYPAD8KEY:
            [self delegateAction: @selector(navigateUpInMatrix:)];
            break;
            
        case DOWNARROWKEY:
        case KEYPAD2KEY:
            [self delegateAction: @selector(navigateDownInMatrix:)];
            break;
            
        default:
            [super keyDown: theEvent];
    }
}


@end
