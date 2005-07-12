/* 
     $Id: GIOutlineViewWithKeyboardSupport.m,v 1.13 2005/05/12 17:41:20 mikesch Exp $

     Copyright (c) 2001, 2002, 2003 by Axel Katerbau. All rights reserved.

     Permission to use, copy, modify and distribute this software and its documentation
     is hereby granted, provided that both the copyright notice and this permission
     notice appear in all copies of the software, derivative works or modified versions,
     and any portions thereof, and that both notices appear in supporting documentation,
     and that credit is given to Axel Katerbau in all documents and publicity
     pertaining to direct or indirect use of this code or its derivatives.

     THIS IS EXPERIMENTAL SOFTWARE AND IT IS KNOWN TO HAVE BUGS, SOME OF WHICH MAY HAVE
     SERIOUS CONSEQUENCES. THE COPYRIGHT HOLDER ALLOWS FREE USE OF THIS SOFTWARE IN ITS
     "AS IS" CONDITION. THE COPYRIGHT HOLDER DISCLAIMS ANY LIABILITY OF ANY KIND FOR ANY
     DAMAGES WHATSOEVER RESULTING DIRECTLY OR INDIRECTLY FROM THE USE OF THIS SOFTWARE
     OR OF ANY DERIVATIVE WORK.

     Further information can be found on the project's web pages
     at http://www.objectpark.org/
*/

#import "GIOutlineViewWithKeyboardSupport.h"
#import <Foundation/NSDebug.h>

#define TAB ((char)'\x09')
#define SPACE ((char)'\x20')
#define BACKSPACE 127
#define RETURN 13
#define ENTER 0x0003

@implementation GIOutlineViewWithKeyboardSupport

- (id)previousExpandedItem
{
    id item;
    int selectedRow;
    int level;
    
    selectedRow = [self selectedRow];    
    item = [self itemAtRow:selectedRow];
    level = [self levelForItem:item];

    if (level)
    {
        while (
               ([self levelForItem:item] > level)
               || (! [self isItemExpanded:item]) 
               && (selectedRow > 0)
               )
        {
            selectedRow -= 1;
            item = [self itemAtRow:selectedRow];
        }
    }
    return item;
}

- (void)keyDown:(NSEvent *)theEvent 
{
    NSString *characters;
    unichar firstChar;
    int selectedRow;
    id item;
    int theModifierFlags;
    id delegate = [self delegate];

    theModifierFlags = [theEvent modifierFlags];    
    selectedRow = [self selectedRow];
    item = [self itemAtRow:selectedRow];
    characters = [theEvent characters];
    firstChar = [characters characterAtIndex:0];

    switch (firstChar)
    {
        case RETURN:
            if ([[self delegate] respondsToSelector:@selector(openSelection:)]) 
            {
                [[self delegate] performSelector:@selector(openSelection:) withObject:self];
            } 
            else 
            {
                [self expandItem:item];
            }
            break;
            
        case NSLeftArrowFunctionKey:
        {
            id myItem;
            int row;
            
            myItem = [self previousExpandedItem];
            row = [self rowForItem:myItem];
            
            [self collapseItem:myItem];
            [self selectRow:row byExtendingSelection:NO];
            [self scrollRowToVisible:row];
            break;
        }
        case SPACE:
            if ([[self delegate] respondsToSelector:@selector(spacebarHitInOutlineView:)])
            {
                [[self delegate] performSelector:@selector(spacebarHitInOutlineView:)
                                      withObject:self];
            }
            break;
/*            if([self isExpandable:item])
            {
                if([self isItemExpanded:item])
                {
                    [self collapseItem:item];
                }
                else
                {
                    [self expandItem:item];
                }
            }
            else
            {
                id myItem;

                myItem = [self previousExpandedItem];
                [self collapseItem:myItem];
                [self selectRow:[self rowForItem:myItem] byExtendingSelection:NO];
            }
            break; */
/*        case RETURN:
        case ENTER:
        { 
            SEL doubleAction = [self doubleAction];
            id delegate = [self delegate];
            [delegate performSelector:doubleAction withObject:self];
        }
            break;
*/        case TAB:
            if(theModifierFlags & NSAlternateKeyMask)
            {
                if ([delegate respondsToSelector:@selector(selectPreviousKeyView:)])
                {
                    [delegate selectPreviousKeyView:self];
                    return;
                }
                else
                {
                    [[self window] selectPreviousKeyView:self];
                    return;
                }
            }
            else
            {
                if ([delegate respondsToSelector:@selector(selectNextKeyView:)])
                {
                    [delegate selectNextKeyView:self];
                    return;
                }
                else
                {
                    [[self window] selectNextKeyView:self];
                }
            }
            break;
        default:
        {
//            NSLog(@"Outline view key: 0x%X", (long)firstChar);
            [super keyDown:theEvent];
        }
    }
}

/*
- (BOOL)shouldCollapseAutoExpandedItemsForDeposited:(BOOL)deposited
{
    return YES;
}
*/
@end


@implementation GIOutlineViewWithKeyboardSupport (Stripes)

- (BOOL) highlightThreads;
{
    return highlightThreads;
}

- (void) setHighlightThreads: (BOOL) aBool
{
    if (highlightThreads != aBool)
    {
        highlightThreads = aBool;
        [self setNeedsDisplay:YES];
    }
}

- (void)drawGridInClipRect:(NSRect)rect
{
    if (highlightThreads)
    {
        NSRange columnRange = [self columnsInRect:rect];
        int i;
        [[NSColor lightGrayColor] set];

        for (i = columnRange.location ; i < NSMaxRange(columnRange) ; i++) {
            NSRect colRect = [self rectOfColumn:i];
            int rightEdge = (int) 0.5 + colRect.origin.x + colRect.size.width;
            [NSBezierPath strokeLineFromPoint: NSMakePoint(-0.5+rightEdge, -0.5+rect.origin.y)
                                      toPoint: NSMakePoint(-0.5+rightEdge, -0.5+rect.origin.y + rect.size.height)];
        }
        [[self superview] setNeedsDisplayInRect:[[self superview] bounds]];
    }
    else
    {
        [super drawGridInClipRect:rect];
    }
}

- (void)highlightSelectionInClipRect:(NSRect)clipRect
/*" Override to draw our background first "*/
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

@implementation NSOutlineView (RowSelection)

- (int) rowForItemEqualTo: (id) item
            startingAtRow: (int) start
{
    int count = [self numberOfRows];
    while (start<count) {
        id rowItem = [self itemAtRow: start];
        if ([item isEqual: rowItem]) return start;
        start++;
    }
    return -1;
}

- (NSArray*) selectedItems
/*" The result is sorted from low to high row indexes. "*/
{
    NSMutableArray* result = [NSMutableArray array];
    NSIndexSet* set = [self selectedRowIndexes];
    if ([set count]) {
        int lastIndex = [set lastIndex];
        int i;
        for (i=[set firstIndex]; i<=lastIndex; i++) {
            if ([set containsIndex: i]) {
                if ([self levelForRow: i]==0) {
                    id item = [self itemAtRow: i];
                    if (item) [result addObject: item];
                }
            }
        }
    }
    return result;
}

- (void) selectItems: (NSArray*) items ordered: (BOOL) ordered
/*" Extends the selection by the rows for the items passed. If ordered==YES, We assume uriStrings are ordered the same way the items are, improving performance. "*/
{
    NSEnumerator* e = [items objectEnumerator];
    NSString* item;
    int row = 0;
    while (item = [e nextObject]) {
        row = [self rowForItemEqualTo: item startingAtRow: ordered ? row : 0];
        if (row>=0) [self selectRow: row byExtendingSelection: YES];
        else if (NSDebugEnabled) NSLog(@"Warning: Unable to select row for item: %@", item);
    }
}


@end
