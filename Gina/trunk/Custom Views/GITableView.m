//
//  GITableView.m
//  Gina
//
//  Created by Axel Katerbau on 14.04.08.
//  Copyright 2008 Objectpark Group. All rights reserved.
//

#import "GITableView.h"
#import "GIMainWindowController.h"

@implementation GITableView

/*" For window keyboard shortcuts "*/
- (void)keyDown:(NSEvent *)event
{	
	if ([self.delegate respondsToSelector:@selector(keyPressed:)])
	{
		if (![self.delegate keyPressed:event])
		{
			[super keyDown:event];
		}
	}
}

@end
