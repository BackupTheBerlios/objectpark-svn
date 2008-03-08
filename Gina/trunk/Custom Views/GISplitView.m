//
//  GISplitView.m
//  Gina
//
//  Created by Axel Katerbau on 08.03.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "GISplitView.h"


@implementation GISplitView

- (float)dividerThickness
{
	return 1.0;
}

- (void)drawDividerInRect:(NSRect)aRect
{
	static NSColor *color = nil;
	
	if (! color)
	{
		color = [[NSColor colorWithCalibratedRed:0.6667 green:0.6667 blue:0.6667 alpha:1.0] retain];
	}
	
	[color set];
	
	//	[[NSGraphicsContext currentContext] setShouldAntialias:NO];
	NSRectFill(aRect);
	//	[[NSGraphicsContext currentContext] setShouldAntialias:YES];
}

@end
