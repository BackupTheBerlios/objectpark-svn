//
//  GIThreadsWindow.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 07.10.06.
//  Copyright 2006 Objectpark Group. All rights reserved.
//

#import "GIThreadsWindow.h"

@implementation GIThreadsWindow

#define SPACEKEY 0x31
#define N_KEY 45
#define B_KEY 11
#define R_KEY 15

- (void)performDelegateAction:(SEL)selector
{
    id delegate = [self delegate];
    if ([delegate respondsToSelector:selector]) 
    {
        [delegate performSelector:selector withObject:self];
    }
	
	// try avoiding unwanted repetition:
	NSEvent *theEvent = [NSApp nextEventMatchingMask:NSKeyUpMask
										   untilDate:[NSDate dateWithTimeIntervalSinceNow:2.0]
											  inMode:NSEventTrackingRunLoopMode
											 dequeue:YES];
	
	[NSApp discardEventsMatchingMask:NSAnyEventMask beforeEvent:theEvent];
}

- (void)sendEvent:(NSEvent *)theEvent
{
	if ([theEvent type] == NSKeyDown) 
	{
		// make sure the shortcuts are only available when no textfield is
		// the first responder:
		if (!([[self firstResponder] isKindOfClass:[NSTextView class]] && [(NSTextView *)[self firstResponder] isFieldEditor]))
		{
			switch ([theEvent keyCode]) 
			{
				case SPACEKEY:
					if ([theEvent modifierFlags] & NSControlKeyMask) // Control pressed
					{
						[self performDelegateAction:@selector(goAhead:)];
					}
					else
					{
						[self performDelegateAction:@selector(goAheadAndMarkSeen:)];
					}
					return;
				case N_KEY:
					[self performDelegateAction:@selector(goNextAndMarkSeen:)];
					return;
				case R_KEY:
					[self performDelegateAction:@selector(toggleReadFlag:)];
					return;
				default:
					break;
			}
		}
	}
	
	[super sendEvent:theEvent];
}

@end
