//
//  OPSizingTextField.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on Sat Jul 24 2004.
//  Copyright (c) 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <AppKit/AppKit.h>


@interface OPSizingTextField : NSTokenField {
    float _lineHeight;
    unsigned maxlines;
    NSTextView* privateFieldEditor;
}

- (void) setMaxLines: (unsigned) maximum;
- (unsigned) maxLines;

@end
