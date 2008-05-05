//
//  OPSizingTokenField.m
//  Gina
//
//  Created by Axel Katerbau on 03.05.08.
//  Copyright 2008 Objectpark Group. All rights reserved.
//

#import "OPSizingTokenField.h"
#import "NSView+ViewMoving.h"

@implementation OPSizingTokenField

@synthesize lastStringValue;

- (id)init
{
    return [super init];
}

/*" common initializer, since -init is not called. "*/
- (void)awake 
{
	maxlines = 5;
    lineHeight = 17;	
}

- (id)initWithFrame:(NSRect)frame
{
    if (self = [super initWithFrame:frame]) 
	{
		[self awake];
    }
	
    return self;
}

- (void)awakeFromNib
{
	[self awake];
}

- (void)dealloc
{
	[lastStringValue release];
	[super dealloc];
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
 unsigned lines = tcs.height / lineHeight;
 if (lines>=5) {
 // begin to scroll
 tcs.height = 10000000.0;
 [tc setContainerSize: tcs];
 return;
 }
 NSRect frame = [self frame];
 frame.size.height += lineHeight;
 frame.origin.y -= lineHeight;
 [self setFrame: frame];
 }
 */

//- (void) setStringValue:(id) value 
//{
//	[super setStringValue: value];	
//}
//
//- (void) setAttributedStringValue: (id) value;
//{
//	[super setAttributedStringValue: value];	
//}
//
//- (void)selectText: (id) text
//{
//	[super selectText: text];
//}
//
//- (BOOL) textView: (id) tv shouldChangeTextInRange: (NSRange) range replacementString: (id) newString;
//{
//	return [super textView: tv shouldChangeTextInRange: range replacementString: newString];
//}



- (void) sizeToFit
{
    NSTextContainer* tc = [self textContainer];
    if (tc && [self currentEditor]) {
		
//		NSLog(@"sizeToFit");
        NSRect frame = [self frame];
        NSRect usedRect = [[tc layoutManager] usedRectForTextContainer: tc];
        NSSize newSize = NSMakeSize(frame.size.width, MAX(lineHeight, MIN(maxlines*lineHeight, usedRect.size.height))+5);
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


//- (BOOL) textShouldBeginEditing: (NSText*) fieldEditor
//{
//	BOOL result = [super textShouldBeginEditing: fieldEditor];
//	if (result) {
////		[[NSNotificationCenter defaultCenter] addObserver: self 
////												 selector: @selector(tvsDidChange:) 
////													 name: NSTextViewDidChangeSelectionNotification
////												   object: fieldEditor];
//	}
//	return result;
//}


// Set Text Container to 1 line height
//NSSize tcs = [tc containerSize];
//tcs.height = lineHeight;
//[tc setContainerSize: tcs];
//NSRect bounds = [self bounds];
// Make sure we get called on textcontainer overflow:
//[lm setDelegate: self];
// return [super textShouldBeginEditing: fieldEditor];
//}
//

//- (BOOL) textShouldEndEditing: (NSText*) textObject
//{
//	NSLog(@"textShouldEndEditing: %@", textObject);
//	return [super textShouldEndEditing: textObject];
//}


- (void)textDidBeginEditing:(NSNotification *)notification
{
    NSTextContainer *tc = [self textContainer];
    NSLayoutManager *lm = [tc layoutManager];
    
    NSFont *typingFont = [[[tc textView] typingAttributes] objectForKey:NSFontAttributeName];
    lineHeight = [lm defaultLineHeightForFont:typingFont];
    
    [super textDidBeginEditing:notification];
}

//- (void)textDidEndEditing:(NSNotification *)notification;
//{
////	[super textDidEditing:notification];
//}

- (void)textDidChange:(NSNotification *)notification
{
//	if (![self.lastStringValue isEqualToString:self.stringValue])
//	{
		// Instead of calling -sizeToFit directly, we call it delayed, to take any changes in the selection, (e.g. introduces by the formatter) into account.
		[self performSelectorOnMainThread:@selector(sizeToFit) withObject:nil waitUntilDone:NO];
		//[self sizeToFit]; 
//		NSLog(@"performing");
//		self.lastStringValue = self.stringValue;
//	}
	
//	NSLog(@"textDidChange: %@", [self stringValue]);
    [super textDidChange:notification];
}

- (void)forceSizeToFit
{
	NSResponder *oldFirst = [[self window] firstResponder];
	[[self window] makeFirstResponder:self];
	[[self window] makeFirstResponder:oldFirst];
}

- (void)setStringValue:(NSString *)aString
{
	[super setStringValue:aString];
	[self performSelector:@selector(forceSizeToFit) withObject:nil afterDelay:0.1];
}

- (BOOL)becomeFirstResponder
{
    if ([super becomeFirstResponder]) 
	{
        [self sizeToFit];
        return YES;
    }
    return NO;
}


//- (void) tvsDidChange: (NSNotification*) n
//{
//	NSLog(@"selection did change: %@", n);
//	[self sizeToFit]; 
//}

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

- (void)selectNextKeyView:(id)sender
{
	[[self window] selectKeyViewFollowingView:self];
}

- (void)selectPreviousKeyView:(id)sender
{
	[[self window] selectKeyViewPrecedingView:self];
}

//- (void)drawRect:(NSRect)aRect
//{
//	[super drawRect: aRect];
//}
//
//- (BOOL)resignFirstResponder
//{
//	return [super resignFirstResponder];
//}

@end
