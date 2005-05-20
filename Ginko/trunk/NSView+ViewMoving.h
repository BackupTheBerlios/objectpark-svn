//
//  NSView+ViewMoving.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 10.12.04.
//  Copyright 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSView (ViewMoving) 

- (void)moveSubviewsWithinHeight:(float)height verticallyBy:(float)diff;

@end
