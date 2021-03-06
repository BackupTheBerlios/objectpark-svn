/* 
     $Id: GIOutlineViewWithKeyboardSupport.h,v 1.2 2004/12/22 15:35:05 mikesch Exp $

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

#import <AppKit/AppKit.h>

@interface GIOutlineViewWithKeyboardSupport : NSOutlineView 
{
    BOOL highlightThreads;
}

@end

@interface GIOutlineViewWithKeyboardSupport (Stripes)

- (BOOL)highlightThreads;
- (void)setHighlightThreads:(BOOL)aBool;

@end

@interface NSOutlineView (RowSelection)

- (int) rowForItemEqualTo: (id) item
            startingAtRow: (int) start;

- (NSArray*) selectedItems;
- (void) selectItems: (NSArray*) items ordered: (BOOL) ordered;

@end