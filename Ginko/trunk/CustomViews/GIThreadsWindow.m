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

- (void)delegateAction:(SEL)selector
{
    id delegate = [self delegate];
    if ([delegate respondsToSelector:selector]) 
    {
        [delegate performSelector:selector withObject:self];
    }
}

- (void)sendEvent:(NSEvent *)theEvent
{
	if ([theEvent type] == NSKeyDown) 
	{
		switch ([theEvent keyCode]) 
		{
			case SPACEKEY:
				if ([theEvent modifierFlags] & NSControlKeyMask) // Control pressed
				{
					[self delegateAction:@selector(goAhead:)];
				}
				else
				{
					[self delegateAction:@selector(goAheadAndMarkSeen:)];
				}

				// try avoiding unwanted repetition?
				theEvent = [NSApp nextEventMatchingMask:NSKeyUpMask
											  untilDate:[NSDate dateWithTimeIntervalSinceNow:2.0]
												 inMode:NSEventTrackingRunLoopMode
												dequeue:YES];
				
				[NSApp discardEventsMatchingMask:NSAnyEventMask beforeEvent:theEvent];
				return;
				break;
			default:
				break;
		}
	}
	
	[super sendEvent:theEvent];
}

@end
