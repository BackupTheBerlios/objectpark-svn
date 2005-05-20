//
//  OPCollapsingSplitView.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 31.12.04.
//  Copyright 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface OPCollapsingSplitView : NSSplitView {
    
    unsigned collapsedSubviewIndex; // NSNotFound if none is collapsed
    float preservedSubviewSize;
    
}

- (void) setSubview: (NSView*) subview isCollapsed: (BOOL) flag;
- (void) moveSplitterBy: (float) moveValue;
- (void) setFirstSubviewSize: (float) firstSize;



@end
