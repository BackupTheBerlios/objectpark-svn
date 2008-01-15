//
//  GIMainWindow.m
//  Gina
//
//  Created by Axel Katerbau on 11.01.08.
//  Copyright 2008 Objectpark Software. All rights reserved.
//

#import "GIMainWindow.h"

@implementation GIMainWindow

/*" For window keyboard shortcuts "*/
- (void)keyDown:(NSEvent *)event
{
	unsigned short keyCode = [event keyCode];
	
	NSLog(@"KeyCode = %d", keyCode);
	
	if ([self.delegate respondsToSelector:@selector(keyPressed:)])
	{
		if (![self.delegate keyPressed:event])
		{
			[super keyDown:event];
		}
	}
}

- (void)dealloc
{
	NSLog(@"GIMainWindow dealloc");
	[super dealloc];
}

@end
