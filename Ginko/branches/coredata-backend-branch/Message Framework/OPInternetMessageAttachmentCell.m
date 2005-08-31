//
//  OPInternetMessageAttachmentCell.m
//  OPMessageServices
//
//  Created by Axel Katerbau on Sun Jan 12 2003.
//  Copyright (c) 2003 Objectpark Development Group. All rights reserved.
//

#import "OPInternetMessageAttachmentCell.h"


@implementation OPInternetMessageAttachmentCell

- (NSSize) cellSize
{
    NSSize result = [[self image] size];
    result.height+= [infoString length] ? 30.0 : 22.0;
    if (result.width<140.0) result.width = 140.0;
    return result;
}


- (NSLineBreakMode) lineBreakMode
{
    return NSLineBreakByTruncatingMiddle;
}

- (NSString*) infoString
{
    return infoString;
}

- (void) setInfoString: (NSString*) newInfo
{
    if (![newInfo isEqualToString: infoString]) {
        [infoString release];
        infoString = [newInfo retain];
    }
}

- (void) drawWithFrame: (NSRect) cellFrame 
                inView: (NSView*) controlView
{
    
    NSString* title          = [self title];
    NSRect    textFrame      = NSInsetRect(cellFrame, 2.0, 2.0);
    
    //[super drawWithFrame:cellFrame inView:controlView];
    
    
     NSImage*  image = [self image];
     NSRect    fullImageRect  = NSMakeRect(0,0,[image size].width, [image size].height);
     NSRect    drawImageRect  = NSOffsetRect(fullImageRect, (cellFrame.size.width-[image size].width)/2.0+cellFrame.origin.x, 5.0+cellFrame.origin.y);
     
     NSParameterAssert(image);
     
     if ([self isHighlighted]) {
         NSColor* backgroundColor = [self highlightColorWithFrame: cellFrame inView: controlView];
         [backgroundColor set];
         NSRectFill(cellFrame);
     }
     
    // Draw it flipped if we are in a flipped view, like NSMatrix:
     [image setFlipped: [controlView isFlipped]];
     
     [image drawInRect: drawImageRect          
              fromRect: fullImageRect 
             operation: NSCompositeSourceOver 
              fraction: 1.0];
     
    
    
    
    // NSLineBreakByTruncatingMiddle
    
     if ([infoString length]) {
         // We have two lines to show:
         title = [NSString stringWithFormat: @"%@\n%@", title, infoString];

         textFrame.origin.y    = NSMaxY(textFrame)-24.0;
         textFrame.size.height = 24.0;
     } else {
         textFrame.origin.y    = NSMaxY(textFrame)-14.0;
         textFrame.size.height = 14.0;
     }
    
    
    static NSDictionary* attributes = nil;
    if (!attributes) {
        NSMutableParagraphStyle* style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        [style setLineBreakMode: [self lineBreakMode]];
        [style setAlignment: NSCenterTextAlignment];
        attributes = [[NSDictionary alloc] initWithObjectsAndKeys: 
            style, NSParagraphStyleAttributeName,
            [NSFont systemFontOfSize: 9], NSFontAttributeName,
            nil, nil];
    }
    
    [title drawWithRect: textFrame
                options: NSStringDrawingUsesLineFragmentOrigin 
             attributes: attributes];
    
    
}

- (void) setTitle: (NSString*) newTitle
{
    // Keep the image around!
    NSImage* image = [[self image] retain];
    
    [super setTitle: newTitle];
    if (image) {
        [self setImage: image];
        [image release];
    }
}

- (void) delloc 
{
    //NSLog(@"Deallocating 0x%x od class %@", self, [self class]);;
    [infoString release];
    [super dealloc];
}

@end
