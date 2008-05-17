//
//  GIOutlineViewWithThreadColoring.m
//  Gina
//
//  Created by Axel Katerbau on 22.10.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import "GIOutlineViewWithThreadColoring.h"

@implementation GIOutlineViewWithThreadColoring

- (BOOL)highlightThreads;
{
    return highlightThreads;
}

- (void)setHighlightThreads:(BOOL)aBool
{
    if (highlightThreads != aBool)
    {
        highlightThreads = aBool;
        [self setNeedsDisplay:YES];
    }
}

- (void)setNeedsDisplayInRect: (NSRect) invalidRect
{
	[super setNeedsDisplayInRect: invalidRect];
}


- (void)drawRow:(NSInteger)row clipRect:(NSRect)clipRect
{
	[super drawRow: row clipRect: clipRect];
}

- (void)drawRect:(NSRect)rect 
{
	[super drawRect:rect];
    // Drawing code here.
}

- (IBAction)delete:(id)sender
// needs validation?
{
	NSIndexSet *selections = [self selectedRowIndexes];
	if (selections.count) 
	{
//		NSUInteger selectionIndex = [[self selectedRowIndexes] lastIndex];
		[self.dataSource performSelector:@selector(moveSelectionToTrash)];
		
//		if ([self numberOfRows] <= selectionIndex)
//		{
//			selectionIndex = [self numberOfRows] - 1;
//		}
//		
//		[self selectRow:selectionIndex byExtendingSelection:NO];
	}
}

- (void)drawGridInClipRect:(NSRect)rect
{
    if (highlightThreads)
    {
        NSRange columnRange = [self columnsInRect:rect];
        int i;
        [[NSColor lightGrayColor] set];
		
        for (i = columnRange.location; i < NSMaxRange(columnRange); i++) 
		{
            NSRect colRect = [self rectOfColumn:i];
            int rightEdge = (int) 0.5 + colRect.origin.x + colRect.size.width;
            [NSBezierPath strokeLineFromPoint:NSMakePoint(-0.5+rightEdge, -0.5+rect.origin.y)
                                      toPoint:NSMakePoint(-0.5+rightEdge, -0.5+rect.origin.y + rect.size.height)];
        }
        [[self superview] setNeedsDisplayInRect:[[self superview] bounds]];
    } 
	else 
	{
        [super drawGridInClipRect:rect];
    }
}

/*" Override to draw our background first "*/
- (void)highlightSelectionInClipRect:(NSRect)clipRect
{
    if (highlightThreads)
    {
        static NSColor *threadColor = nil;
        
        if (! threadColor)
        {
            threadColor = [[NSColor colorWithCalibratedRed:0.92 green:0.93 blue:1.0 alpha:1.0] retain];
        }
        
        float rowHeight = [self rowHeight] + [self intercellSpacing].height;
        NSRect visibleRect = [self visibleRect];
        NSRect highlightRect;
		
        highlightRect.origin = NSMakePoint(NSMinX(visibleRect), ((int)(NSMinY(clipRect)/rowHeight)*rowHeight));
        highlightRect.size   = NSMakeSize(NSWidth(visibleRect), (rowHeight - [self intercellSpacing].height) + 1);
		
        while (NSMinY(highlightRect) < NSMaxY(clipRect))
        {
            NSRect clippedHighlightRect = NSIntersectionRect(highlightRect, clipRect);
            int row = (int)((NSMinY(highlightRect)+rowHeight/2.0)/rowHeight);
            if ([self levelForRow:row] > 0)
            {
                [threadColor set];
                NSRectFill(clippedHighlightRect);
            }
            highlightRect.origin.y += rowHeight;
        }
    }
    [super highlightSelectionInClipRect:clipRect];	// call superclass's behavior
}

@end
