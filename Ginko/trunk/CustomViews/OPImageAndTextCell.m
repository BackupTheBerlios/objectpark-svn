/*
 $Id: OPImageAndTextCell.m,v 1.3 2004/01/13 17:24:59 westheide Exp $

 Copyright (c) 2003 by Axel Katerbau. All rights reserved.

 Permission to use, copy, modify and distribute this software and its documentation
 is hereby granted, provided that both the copyright notice and this permission
 notice appear in all copies of the software, derivative works or modified versions,
 and any portions thereof, and that both notices appear in supporting documentation,
 and that credit is given to Axel Katerbau in all documents and publicity
 pertaining to direct or indirect use of this code or its derivatives.

 THIS IS EXPERIMENTAL SOFTWARE AND IT IS KNOWN TO HAVE BUGS, SOME OF WHICH MAY HAVE
 SERIOUS CONSEQUENCES. THE COPYRIGHT HOLDER ALLOWS FREE USE OF THIS SOFTWARE IN ITS
 "AS IS" CONDITION. THE COPYRIGHT HOLDER DISCLAIMS ANY LIABILITY OF ANY KIND FOR ANY
 DAMAGES WHATSOEVER RESULTING DIRECTLY OR INDIRECTLY FROM THE USE OF THIS SOFTWARE
 OR OF ANY DERIVATIVE WORK.

 Further information can be found on the project's web pages
 at http://www.objectpark.org/Ginko.html
 */

#import "OPImageAndTextCell.h"


@implementation OPImageAndTextCell

- (void)setImage:(NSImage *)anImage
{
    _image = anImage;
}

- (NSImage *)image
{
    return _image;
}

- (void)editWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject event:(NSEvent *)theEvent
{
    NSRect textFrame, imageFrame;

    NSDivideRect(aRect, &imageFrame, &textFrame, 3 + [_image size].width, NSMinXEdge);

    [super editWithFrame:textFrame inView:controlView editor:textObj delegate:anObject event:theEvent];
}

- (void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(int)selStart length:(int)selLength
{
    NSRect textFrame, imageFrame;

    NSDivideRect(aRect, &imageFrame, &textFrame, 3 + [_image size].width, NSMinXEdge);

    [super selectWithFrame:textFrame inView:controlView editor:textObj delegate:anObject start:selStart length:selLength];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    NSRect mutableCellFrame;
    mutableCellFrame = cellFrame;
    
    if(_image)
    {
        NSRect imageFrame;
        NSSize imageSize;

        imageSize = [_image size];

        NSDivideRect(mutableCellFrame, &imageFrame, &mutableCellFrame, 3 + [_image size].width, NSMinXEdge);
        
        if ([self drawsBackground])
        {
            [[self backgroundColor] set];
            NSRectFill(imageFrame);
        }

        imageFrame.origin.x += 3;
        
        imageFrame.size = imageSize;
        
        if ([controlView isFlipped])
        {
            imageFrame.origin.y = imageFrame.origin.y + ceil((mutableCellFrame.size.height + imageFrame.size.height) / 2) -1;
        }
        else
        {
            imageFrame.origin.y = imageFrame.origin.y - ceil((mutableCellFrame.size.height + imageFrame.size.height) / 2) +1;
        }
        [_image compositeToPoint:imageFrame.origin operation:NSCompositeSourceOver];
    }
    [super drawWithFrame:mutableCellFrame inView:(NSView *)controlView];         
}

- (NSSize)cellSize
{
    NSSize cellSize = [super cellSize];
    float cellWidth = cellSize.width;
    
    cellWidth += (_image != nil ? [_image size].width : 0) + 3;
    return NSMakeSize(cellWidth, cellSize.height);
}

@end
