//
//  GISeparatorButton.m
//  Gina
//
//  Created by Axel Katerbau on 08.03.08.
//  Copyright 2008 Objectpark Group. All rights reserved.
//

#import "GISeparatorButton.h"


@implementation GISeparatorButton

- (void)resetCursorRects
{
	[self addCursorRect:[self bounds] cursor:[NSCursor resizeLeftRightCursor]];
}

- (CGFloat) minWidthSubview1
{
	if ([splitView.delegate respondsToSelector: @selector(splitView:constrainMinCoordinate:ofSubviewAt:)]) {
		return [splitView.delegate splitView: splitView constrainMinCoordinate: 0.0 ofSubviewAt: 0];
	}
	return 0.0;
}

- (CGFloat) minWidthSubview2
{
	if ([splitView.delegate respondsToSelector: @selector(splitView:constrainMinCoordinate:ofSubviewAt:)]) {
		return [splitView.delegate splitView: splitView constrainMinCoordinate: 0.0 ofSubviewAt: 1];
	}
	return 0.0;
}


- (void)mouseDown:(NSEvent *)theEvent
{
	// if the event is a double click we let the delegate deal with it
//    if ([theEvent clickCount] > 1) 
//	{
//		id kfDelegate = [splitView delegate];
//        if ([kfDelegate respondsToSelector:@selector(splitView:didDoubleClickInDivider:)])
//        {
//            [kfDelegate splitView:self didDoubleClickInDivider:0];
//            return;
//        }
//    }
	
	NSPoint eventLocation = [theEvent locationInWindow];
	NSPoint separatorLocation = [self frame].origin;
	
	dragOffset = NSMakePoint(eventLocation.x - separatorLocation.x, eventLocation.y - separatorLocation.y);
	
	[[NSCursor resizeLeftRightCursor] push];
	
	return;
}

- (void)mouseUp:(NSEvent *)theEvent
{
	[NSCursor pop];
	return;
}

- (void)mouseDragged:(NSEvent *)theEvent
{
	//NSLog(@"mouseDragged: %@", theEvent);
	
	float locationX = [theEvent locationInWindow].x - dragOffset.x;
	//	float deltaX = [self convertPoint:[self frame].origin toView:nil].x - locationX;
	float deltaX = locationX - [self frame].origin.x;
	
	NSView *subview1 = [[splitView subviews] objectAtIndex:0];
	NSView *subview2 = [[splitView subviews] objectAtIndex:1];
	
	NSRect frame1 = [subview1 frame];
	NSRect frame2 = [subview2 frame];
	
	frame1.size.width += deltaX;
	frame2.size.width -= deltaX;
	
	if (frame1.size.width < self.minWidthSubview1) 
	{
		frame1.size.width = self.minWidthSubview1;
		frame2.size.width = [splitView bounds].size.width - self.minWidthSubview1 - [splitView dividerThickness];
	}
	
	if (frame2.size.width < self.minWidthSubview2) 
	{
		frame2.size.width = self.minWidthSubview2;
		frame1.size.width = [splitView bounds].size.width - self.minWidthSubview2 - [splitView dividerThickness];
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:NSSplitViewWillResizeSubviewsNotification object:splitView];
	
	[subview1 setFrame:frame1];
    [subview2 setFrame:frame2];
	
    [splitView adjustSubviews];
    [splitView setNeedsDisplay:YES];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:NSSplitViewDidResizeSubviewsNotification object:splitView];
}

@end
