//
//  OPCollapsingSplitView.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 31.12.04.
//  Copyright 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// this class is unfinished. some methods don't work!

@interface OPCollapsingSplitView : NSSplitView {
    
    float preservedSubviewSize;
    
}

- (void) setSubview: (NSView*) subview isCollapsed: (BOOL) flag;
- (void) moveSplitterBy: (float) moveValue;
- (void) setFirstSubviewSize: (float) firstSize;
- (BOOL) isSubviewCollapsed: (NSView*) subview;
- (NSView*) collapsedSubview;

@end
