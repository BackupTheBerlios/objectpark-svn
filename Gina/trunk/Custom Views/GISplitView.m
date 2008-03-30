//
//  GISplitView.m
//  Gina
//
//  Created by Axel Katerbau on 08.03.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "GISplitView.h"


@implementation GISplitView

@synthesize dividerThickness;

- (id)initWithFrame:(NSRect)aFrame
{
	self = [super initWithFrame:aFrame];
	
	self.dividerThickness = 1.0;
	
	return self;
}

- (void)awakeFromNib
{
	self.dividerThickness = 1.0;
}

- (void)drawDividerInRect:(NSRect)aRect
{
	static NSColor *color = nil;
	static NSColor *gradientStartColor = nil;
	static NSColor *gradientEndColor = nil;
	static NSGradient *gradient = nil;
	
	if (! color)
	{
		color = [[NSColor colorWithCalibratedRed:0.6667 green:0.6667 blue:0.6667 alpha:1.0] retain];
		gradientStartColor = [[NSColor colorWithCalibratedRed:0.998 green:0.998 blue:0.998 alpha:1.0] retain];
		gradientEndColor = [[NSColor colorWithCalibratedRed:0.874 green:0.874 blue:0.874 alpha:1.0] retain];
		
		gradient = [[NSGradient alloc] initWithStartingColor:gradientStartColor endingColor:gradientEndColor];
	}
	
	//	[[NSGraphicsContext currentContext] setShouldAntialias:NO];

	if (self.dividerThickness == 1.0)
	{
		[color set];
		NSRectFill(aRect);
	}
	else
	{
		[gradient drawInRect:aRect angle:90.0];
		[color set];
		
		NSRectFill(NSMakeRect(aRect.origin.x, aRect.origin.y, aRect.size.width, 1.0));
		NSRectFill(NSMakeRect(aRect.origin.x, aRect.origin.y + (aRect.size.height - 1.0), aRect.size.width, 1.0));
		NSImage *dotImage = [NSImage imageNamed:@"SplitViewDot"];
		[dotImage drawAtPoint:NSMakePoint(round(aRect.origin.x + ((aRect.size.width + dotImage.size.width) / 2)), aRect.origin.y + (dotImage.size.height / 2)) fromRect:NSMakeRect(0, 0, dotImage.size.width, dotImage.size.height) operation:NSCompositeSourceAtop fraction:1.0];
	}
	
	//	[[NSGraphicsContext currentContext] setShouldAntialias:YES];
}

@end
