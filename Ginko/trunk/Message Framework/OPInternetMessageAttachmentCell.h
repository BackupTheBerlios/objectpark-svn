//
//  OPInternetMessageAttachmentCell.h
//  OPMessageServices
//
//  Created by Axel Katerbau on Sun Jan 12 2003.
//  Copyright (c) 2003 Objectpark Development Group. All rights reserved.
//

#import <AppKit/AppKit.h>

@interface OPInternetMessageAttachmentCell: NSTextAttachmentCell
{
    @private
    NSString* infoString;
}

- (NSString*) infoString;
- (void) setInfoString: (NSString*) newInfo;

@end


