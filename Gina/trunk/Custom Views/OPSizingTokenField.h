//
//  OPSizingTokenField.h
//  Gina
//
//  Created by Axel Katerbau on 03.05.08.
//  Copyright 2008 Objectpark Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface OPSizingTokenField : NSTokenField 
{
    float lineHeight;
    unsigned maxlines;
    NSTextView *privateFieldEditor;
	NSString *lastStringValue;
}

@property (retain) NSString *lastStringValue;

- (void)setMaxLines:(unsigned)maximum;
- (unsigned)maxLines;

- (void)selectNextKeyView:(id)sender;
- (void)selectPreviousKeyView:(id)sender;

@end
