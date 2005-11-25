//
//  OPSizingTextField.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on Sat Jul 24 2004.
//  Copyright (c) 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "OPSizingTextField.h"
#import "NSView+ViewMoving.h"
#import <OPDebug/OPLog.h>

@implementation OPSizingTextField


- (id) init
{
    NSLog(@"Init Called!");
    return [super init];
}


- (id) initWithFrame: (NSRect) frame
{
    if (self = [super initWithFrame: frame]) {
        //[self setDelegate: self];
    }
    maxlines = 5;
    _lineHeight = 17;
    return self;
}

- (void) awakeFromNib
{
    maxlines = 5;
    _lineHeight = 17;
    //[self setDelegate: self];
    //heightDiff = [self size].height - [self container]
}


/*
- (NSLayoutManager*) layoutManager
{
    return [(NSTextView*)[[self window] fieldEditor: NO forObject: self] layoutManager];
}
*/

/*
- (NSText*) currentEditor
{
    
    NSText* result = [super currentEditor];
    NSLog(@"%@ returning current editor: %@", self, result);
    return result;
     
    if (!privateFieldEditor) {
        privateFieldEditor = [[NSTextView alloc] initWithFrame: [self frame]];
        [privateFieldEditor setString: [self stringValue]];
    }
    NSLog(@"%@ returning current editor: %@", self, privateFieldEditor);

    return privateFieldEditor;
}
*/

// use textContainerInset;

- (void) moveSisterViewsBy:(float)diff
{
    [[self superview] moveSubviewsWithinHeight:([self frame].origin.y - 1) verticallyBy:diff];

    /*
    BOOL didMove = NO;
    NSRect myFrame = [self frame];
    NSEnumerator* e = [[[self superview] subviews] objectEnumerator];
    NSView* subview;
    while (subview = [e nextObject]) {
        NSRect frame = [subview frame];
        if (frame.origin.y<myFrame.origin.y) {
            if ([subview autoresizingMask] & NSViewHeightSizable) {
                // size height
                frame.size.height+=diff;
            } else {
                frame.origin.y+=diff;
            }
            [subview setFrame: frame];
            didMove = YES;
        }
    }   
    if (didMove) [[self superview] setNeedsDisplay: YES];
     */
}

- (NSTextContainer*) textContainer
{
    return [(NSTextView*)[self currentEditor] textContainer];
    //return [(NSTextView*)[[self window] fieldEditor: NO forObject: self] textContainer];
}

/*
- (void) addRow: (NSLayoutManager*) lm
{ 
    NSTextContainer* tc = [[lm textContainers] lastObject];
    NSSize tcs = [tc containerSize];
    // Calculate the current number of lines:
    unsigned lines = tcs.height / _lineHeight;
    if (lines>=5) {
        // begin to scroll
        tcs.height = 10000000.0;
        [tc setContainerSize: tcs];
        return;
    }
    NSRect frame = [self frame];
    frame.size.height += _lineHeight;
    frame.origin.y -= _lineHeight;
    [self setFrame: frame];
}
*/


- (void) sizeToFit
{
    NSTextContainer* tc = [self textContainer];
    if (tc && [self currentEditor]) {
        NSRect frame = [self frame];
        NSRect usedRect = [[tc layoutManager] usedRectForTextContainer: tc];
        NSSize newSize = NSMakeSize(frame.size.width, MAX(_lineHeight, MIN(maxlines*_lineHeight, usedRect.size.height))+5);
        if (frame.size.height!=newSize.height) {
            float diff = frame.size.height-newSize.height;
            [self moveSisterViewsBy: diff];
            frame.origin.y += diff; // move down
            frame.size = newSize;
            [self setFrame: frame];
        }
    }
}

- (void) setFrame: (NSRect) newFrame
{
    NSRect oldFrame = [self frame];
    [super setFrame: newFrame];
    if (oldFrame.size.width!=newFrame.size.width) {
        [self sizeToFit];
    }
}

- (void) setMaxLines: (unsigned) maximum
{
    maxlines = maximum;
}

- (unsigned) maxLines
/*" Returns the maximum number of lines to use for this field. Defaults to 5. "*/
{
    return maxlines;
}

/*
- (BOOL) textShouldBeginEditing: (NSText*) fieldEditor
{

    
    // Set Text Container to 1 line height
    //NSSize tcs = [tc containerSize];
    //tcs.height = _lineHeight;
    //[tc setContainerSize: tcs];
    //NSRect bounds = [self bounds];
    // Make sure we get called on textcontainer overflow:
    //[lm setDelegate: self];
    return [super textShouldBeginEditing: fieldEditor];
}
*/

//- (BOOL)textShouldEndEditing: (NSText*) textObject;
- (void) textDidBeginEditing: (NSNotification*) notification
{
    NSTextContainer* tc = [self textContainer];
    NSLayoutManager* lm = [tc layoutManager];
    
    NSFont* typingFont = [[[tc textView] typingAttributes] objectForKey: NSFontAttributeName];
    _lineHeight = [lm defaultLineHeightForFont: typingFont];
    
    //[self sizeToFit];
    [super textDidBeginEditing: notification];
}
//- (void) textDidEndEditing: (NSNotification*) notification;

- (void) textDidChange: (NSNotification*) notification
{
    [self sizeToFit]; 
    [super textDidChange: notification];
}

- (BOOL) becomeFirstResponder
{
    if ([super becomeFirstResponder]) {
        [self sizeToFit];
        return YES;
    }
    return NO;
}



/*
- (void) layoutManager: (NSLayoutManager*) lm
    didCompleteLayoutForTextContainer: (NSTextContainer*) textContainer
		 atEnd: (BOOL) layoutFinishedFlag
{
    if (!textContainer) {
        // no "last" text container, so we add a row:
        [self addRow: lm];
    }
}
*/


@end
