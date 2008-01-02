//
//  NSBezierPath+RoundedRect.h
//  Menu Calendar
//
//  Created by Axel Katerbau on Sun Jul 18 2004.
//  Copyright (c) 2004 Objectpark Software. All rights reserved.
//

#import <AppKit/AppKit.h>


@interface NSBezierPath (RoundedRect)

+ (NSBezierPath *)bezierPathWithRoundRectInRect:(NSRect)rect radius:(float)radius;
+ (NSBezierPath *)bezierPathWithBottomRoundRectInRect:(NSRect)rect radius:(float)radius;

@end
