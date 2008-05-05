//
//  GIMainWindow.m
//  Gina
//
//  Created by Axel Katerbau on 11.01.08.
//  Copyright 2008 Objectpark Software. All rights reserved.
//

#import "GIMainWindow.h"

@implementation GIMainWindow

/*" For window keyboard shortcuts "*/
- (void)keyDown:(NSEvent *)event
{
	unsigned short keyCode = [event keyCode];
	
	NSLog(@"KeyCode = %d", keyCode);
	
	if ([self.delegate respondsToSelector:@selector(keyPressed:)])
	{
		if (![self.delegate keyPressed:event])
		{
			[super keyDown:event];
		}
	}
}

- (void)dealloc
{
	NSLog(@"GIMainWindow dealloc");
	[super dealloc];
}

//- (NSSize)windowWillResize:(NSWindow *)window toSize:(NSSize)proposedFrameSize
//{
//	return [self.delegate windowWillResize: window toSize:proposedFrameSize];
//}
//
//
//- (BOOL)setFrameUsingName:(NSString *)name force:(BOOL)force
//{
//	return [super setFrameUsingName: name force:force];
//}
//
//- (BOOL)setFrameUsingName:(NSString *)name 
//{
//	NSString* framePos = [[NSUserDefaults standardUserDefaults] stringForKey: [@"NSWindow Frame " stringByAppendingString: name]];
//	NSRect frameRect = NSRectFromString(framePos);
//	return [super setFrameUsingName: name];
//}

- (BOOL)makeFirstResponder:(id)bla
{
//	NSLog(@"make first responder: %@", bla);
	
	return [super makeFirstResponder:bla];
}

@end
