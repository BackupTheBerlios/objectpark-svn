//
//  OPForm.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on Fri Jul 23 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface OPForm : NSView {
    float titleWidth;
}



- (float) titleWidth;
- (void) setTitleWidth: (float) newWidth;

- (NSTextField*) titleFieldAtIndex: (unsigned) index;
- (NSTextField*) inputFieldAtIndex: (unsigned) index;
- (unsigned) indexOfField: (NSTextField*) field;


@end
