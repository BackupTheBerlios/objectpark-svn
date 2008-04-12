//
//  OPMenuButton.m
//
//  Created by Axel Katerbau on 04.03.08.
//  Copyright 2008 Objectpark Group. All rights reserved.
//

#import "OPMenuButton.h"

@implementation OPMenuButton

- (void)mouseDown:(NSEvent *)theEvent
{
	[[self cell] setHighlighted:YES];
	[self display];
	[NSMenu popUpContextMenu:self.menu withEvent:theEvent forView:self]; 
	[[self cell] setHighlighted:NO];
}

@end
