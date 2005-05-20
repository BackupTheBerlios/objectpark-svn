//
//  OPForm.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on Fri Jul 23 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "OPForm.h"


@implementation OPForm

- (id) initWithFrame: (NSRect) frame
{
    if (self= [super init]) {
        titleWidth = 150;
    }
    return self;
}

- (void) adjustSubviews
{
    
}

/*
- (NSTextField*) addFieldWithTitle: (NSString*) title
{
    NSTextField 
}
*/


- (float) titleWidth
{
    return titleWidth;
}
/*
- (void) setTitleWidth: (float) newWidth;

- (NSTextField*) titleFieldAtIndex: (unsigned) index;
- (NSTextField*) inputFieldAtIndex: (unsigned) index;
- (unsigned) indexOfField: (NSTextField*) field;
*/

@end
