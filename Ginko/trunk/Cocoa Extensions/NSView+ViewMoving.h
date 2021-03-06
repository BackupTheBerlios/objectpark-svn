//
//  NSView+ViewMoving.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 10.12.04.
//  Copyright 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <AppKit/AppKit.h>

@interface NSView (ViewMoving) 

- (void) moveSubviewsWithinHeight: (float) height verticallyBy: (float) diff;
- (void) moveSubviewsWithinWidth: (float) width horizontallyBy: (float) diff;

@end
