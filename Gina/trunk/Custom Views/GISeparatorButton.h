//
//  GISeparatorButton.h
//  Gina
//
//  Created by Axel Katerbau on 08.03.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface GISeparatorButton : NSImageView 
{
	IBOutlet NSSplitView *splitView;
	NSPoint dragOffset;
}

- (void)setMinWidthSubview1:(CGFloat)aWidth;
- (void)setMinWidthSubview2:(CGFloat)aWidth;

@end
