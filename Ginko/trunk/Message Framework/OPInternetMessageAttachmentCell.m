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
    result.height+=12.0;
    return result;
}

- (void) drawWithFrame: (NSRect) cellFrame 
                inView: (NSView*) controlView
{
    [super drawWithFrame:cellFrame inView:controlView];
}

@end
