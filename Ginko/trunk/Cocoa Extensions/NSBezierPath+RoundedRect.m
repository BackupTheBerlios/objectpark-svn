//
//  NSBezierPath+RoundedRect.m
//  Menu Calendar
//
//  Created by Axel Katerbau on Sun Jul 18 2004.
//  Copyright (c) 2004 Objectpark Software. All rights reserved.
//

#import "NSBezierPath+RoundedRect.h"


@implementation NSBezierPath (RoundedRect)

// for flipped views
NSPoint topLeftOfRect(NSRect rect) { return rect.origin; } 
NSPoint topRightOfRect(NSRect rect) { return NSMakePoint(NSMaxX(rect), NSMinY(rect)); } 
NSPoint bottomRightOfRect(NSRect rect) { return NSMakePoint(NSMaxX(rect), NSMaxY(rect)); }
NSPoint bottomLeftOfRect(NSRect rect)  { return NSMakePoint(NSMinX(rect), NSMaxY(rect)); }

/* not verified ones...may be buggy!
NSPoint centerOfRect(NSRect rect) { return NSMakePoint(NSMidX(rect), NSMidY(rect)); } 
NSPoint topCenterOfRect(NSRect rect) { return NSMakePoint(NSMidX(rect), NSMinY(rect)); } 
NSPoint leftCenterOfRect(NSRect rect) { return NSMakePoint(NSMinX(rect), NSMidY(rect)); } 
NSPoint bottomCenterOfRect(NSRect rect) { return NSMakePoint(NSMidX(rect), NSMaxY(rect)); }
NSPoint rightCenterOfRect(NSRect rect) { return NSMakePoint(NSMidX(rect), NSMidY(rect)); } 
*/

+ (NSBezierPath *)bezierPathWithRoundRectInRect:(NSRect)rect radius:(float)radius
    /*"This method adds the traditional Macintosh rounded-rectangle to 
    NSBezierPath's repertoire.  Take care that radius is smaller than half 
    the height or width of rect, or some peculiar artifacts may result."*/ 
{     
    NSRect innerRect = NSInsetRect(rect, radius, radius); 
    NSBezierPath *path = [self bezierPath]; 
    
    [path appendBezierPathWithArcWithCenter:topLeftOfRect(innerRect)
                                     radius:radius 
                                 startAngle:180.0 
                                   endAngle:270.0];
    
    [path relativeLineToPoint:NSMakePoint(NSWidth(innerRect), 0.0)]; 
    
    
    [path appendBezierPathWithArcWithCenter:topRightOfRect(innerRect)
                                     radius:radius 
                                 startAngle:270.0 
                                   endAngle:360.0]; 
    
    [path relativeLineToPoint:NSMakePoint(0.0, NSHeight(innerRect))]; 
    
    
    [path appendBezierPathWithArcWithCenter:bottomRightOfRect(innerRect)
                                     radius:radius 
                                 startAngle:0.0 
                                   endAngle:90.0];
    
    [path relativeLineToPoint:NSMakePoint( - NSWidth(innerRect), 0.0)];
    
    [path appendBezierPathWithArcWithCenter:bottomLeftOfRect(innerRect)
                                     radius:radius 
                                 startAngle:90.0 
                                   endAngle:180.0];
    
    [path closePath];
    
    return path;
}

+ (NSBezierPath *)bezierPathWithBottomRoundRectInRect:(NSRect)rect radius:(float)radius
{     
    NSRect innerRect = NSInsetRect(rect, radius, radius); 
    NSBezierPath *path = [self bezierPath]; 
    
    [path appendBezierPathWithArcWithCenter:topLeftOfRect(innerRect)
                                     radius:radius 
                                 startAngle:180.0 
                                   endAngle:270.0];
    
    [path relativeLineToPoint:NSMakePoint(NSWidth(innerRect), 0.0)]; 
    
    [path appendBezierPathWithArcWithCenter:topRightOfRect(innerRect)
                                     radius:radius 
                                 startAngle:270.0 
                                   endAngle:360.0]; 
    
    [path relativeLineToPoint:NSMakePoint(0.0, NSHeight(rect))]; 
    
    
    [path relativeLineToPoint:NSMakePoint( - NSWidth(rect), 0.0)];
    
    [path closePath];
    
    return path;
}

@end
