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

@interface FakeOutlineView : NSTableView
{
    int _numberOfRows;
    struct __NSOVRowEntry *_rowEntryTree;
    struct __CFDictionary *_itemToEntryMap;
    int _unused2;
    int _unused3;
    int _unused1;
    NSTableColumn *_outlineTableColumn;
    BOOL _initedRows;
    BOOL _indentationMarkerInCell;
    int _indentationPerLevel;
    NSButtonCell *_outlineCell;
    struct _NSRect _trackingOutlineFrame;
    NSMouseTracker *_tracker;
    id _unused4;
    struct __OvFlags _ovFlags;
    id _ovLock;
    long *_indentArray;
    long _originalWidth;
    id _expandSet;
    id _expandSetToExpandItemsInto;
    long _indentArraySize;
    NSButtonCell *_trackingOutlineCell;
    int _trackingRow;
    id _ovReserved;
}

+ (void)initialize;
+ (void)_delayedFreeRowEntryFreeList;
+ (void)_initializeRegisteredDefaults;
+ (BOOL)_shouldAllowAutoExpandItemsDuringDragsDefault;
+ (BOOL)_shouldAllowAutoCollapseItemsDuringDragsDefault;
+ (BOOL)_shouldRequireAutoCollapseOutlineAfterDropsDefault;
- (void)_commonInit;
- (void)_goneMultiThreaded;
- (void)_goneSingleThreaded;
- (id)init;
- (id)initWithFrame:(struct _NSRect)fp8;
- (void)_finishedTableViewInitWithCoder;
- (id)initWithCoder:(id)fp8;
- (void)dealloc;
- (void)finalize;
- (void)encodeWithCoder:(id)fp8;
- (BOOL)isExpandable:(id)fp8;
- (BOOL)_shouldContinueExpandAtLevel:(int)fp8 beganAtLevel:(int)fp12;
- (void)_expandItemEntry:(struct __NSOVRowEntry *)fp8 expandChildren:(BOOL)fp12 startLevel:(int)fp16;
- (void)_expandItemEntry:(struct __NSOVRowEntry *)fp8 expandChildren:(BOOL)fp12;
- (void)_batchExpandItemsWithItemEntries:(struct __CFArray *)fp8 expandChildren:(BOOL)fp12;
- (void)expandItem:(id)fp8;
- (void)expandItem:(id)fp8 expandChildren:(BOOL)fp12;
- (void)_collapseItemEntry:(struct __NSOVRowEntry *)fp8 collapseChildren:(BOOL)fp12 clearExpandState:(BOOL)fp16 recursionLevel:(int)fp20;
- (void)_batchCollapseItemsWithItemEntries:(struct __CFArray *)fp8 collapseChildren:(BOOL)fp12 clearExpandState:(BOOL)fp16;
- (void)_batchCollapseItemsWithItemEntries:(struct __CFArray *)fp8 collapseChildren:(BOOL)fp12;
- (void)collapseItem:(id)fp8;
- (void)collapseItem:(id)fp8 collapseChildren:(BOOL)fp12;
- (void)_collapseItem:(id)fp8 collapseChildren:(BOOL)fp12 clearExpandState:(BOOL)fp16;
- (void)_endEditingIfEditedCellIsChildOfItemEntry:(struct __NSOVRowEntry *)fp8;
- (void)_adjustEditedCellLocation;
- (void)_scrollFieldEditorToVisible:(id)fp8;
- (BOOL)_supportsVariableHeightRows;
- (float)_sendDelegateHeightOfRow:(int)fp8;
- (void)_adjustSelectionForItemEntry:(struct __NSOVRowEntry *)fp8 numberOfRows:(int)fp12 adjustFieldEditorIfNecessary:(BOOL)fp16;
- (void)_calcOutlineColumnWidth;
- (void)_resizeOutlineColumn;
- (void)reloadData;
- (void)reloadItem:(id)fp8;
- (void)reloadItem:(id)fp8 reloadChildren:(BOOL)fp12;
- (void)setIndentationPerLevel:(float)fp8;
- (float)indentationPerLevel;
- (void)setIndentationMarkerFollowsCell:(BOOL)fp8;
- (BOOL)indentationMarkerFollowsCell;
- (void)setOutlineTableColumn:(id)fp8;
- (id)outlineTableColumn;
- (void)removeTableColumn:(id)fp8;
- (void)setAutoresizesOutlineColumn:(BOOL)fp8;
- (BOOL)autoresizesOutlineColumn;
- (void)_postItemWillExpandNotification:(id)fp8;
- (void)_postItemWillCollapseNotification:(id)fp8;
- (void)_postItemDidExpandNotification:(id)fp8;
- (void)_postItemDidCollapseNotification:(id)fp8;
- (void)setDataSource:(id)fp8;
- (void)setDelegate:(id)fp8;
- (int)numberOfRows;
- (void)_autoscrollForDraggingInfo:(id)fp8 timeDelta:(double)fp12;
- (void)mouseDown:(id)fp8;
- (void)_drawOutlineCell:(id)fp8 withFrame:(struct _NSRect)fp12 inView:(id)fp28;
- (void)_highlightOutlineCell:(id)fp8 highlight:(BOOL)fp12 withFrame:(struct _NSRect)fp16 inView:(id)fp32;
- (void)_doUserExpandOrCollapseOfItem:(id)fp8 isExpand:(BOOL)fp12 optionKeyWasDown:(BOOL)fp16;
- (struct __CFArray *)_createSelectedRowEntriesArrayIncludingExpandable:(BOOL)fp8 includingUnexpandable:(BOOL)fp12 withCurrentExpandState:(BOOL)fp16;
- (void)keyDown:(id)fp8;
- (BOOL)mouseTracker:(id)fp8 shouldStartTrackingWithEvent:(id)fp12;
- (BOOL)mouseTracker:(id)fp8 shouldContinueTrackingWithEvent:(id)fp12;
- (BOOL)mouseTracker:(id)fp8 didStopTrackingWithEvent:(id)fp12;
- (BOOL)_dataSourceIsItemExpandable:(id)fp8;
- (id)_dataSourceChild:(int)fp8 ofItem:(id)fp12;
- (int)_dataSourceNumberOfChildrenOfItem:(id)fp8;
- (id)_dataSourceValueForColumn:(id)fp8 row:(int)fp12;
- (void)_dataSourceSetValue:(id)fp8 forColumn:(id)fp12 row:(int)fp16;
- (void)_delegateWillDisplayCell:(id)fp8 forColumn:(id)fp12 row:(int)fp16;
- (void)_delegateWillDisplayOutlineCell:(id)fp8 forColumn:(id)fp12 row:(int)fp16;
- (void)_sendDelegateWillDisplayOutlineCell:(id)fp8 inOutlineTableColumnAtRow:(int)fp12;
- (BOOL)_delegateRespondsToGetToolTip;
- (id)_sendDelegateToolTipForCell:(id)fp8 tableColumn:(id)fp12 rect:(struct _NSRect *)fp16 row:(int)fp20 mouseLocation:(struct _NSPoint)fp24;
- (void)_sendDelegateWillDisplayCell:(id)fp8 forColumn:(id)fp12 row:(int)fp16;
- (BOOL)_wantsLiveResizeToUseCachedImage;
- (id)_alternateAutoExpandImageForOutlineCell:(id)fp8 inRow:(int)fp12 withFrame:(struct _NSRect)fp16;
- (void)_debugDrawRowNumberInCell:(id)fp8 withFrame:(struct _NSRect)fp12 forRow:(int)fp28;
- (void)drawRow:(int)fp8 clipRect:(struct _NSRect)fp12;
- (void)_drawContentsAtRow:(int)fp8 column:(int)fp12 clipRect:(struct _NSRect)fp16;
- (struct _NSRect)frameOfCellAtColumn:(int)fp8 row:(int)fp12;
- (struct _NSRect)_frameOfOutlineCellAtRow:(int)fp8;
- (void)_redisplayAndResizeFromRow:(int)fp8;
- (BOOL)_userCanChangeSelection;
- (BOOL)_sendDelegateCanSelectRow:(int)fp8 byExtendingSelection:(BOOL)fp12;
- (BOOL)_sendDelegateCanSelectColumn:(int)fp8 byExtendingSelection:(BOOL)fp12;
- (struct __NSOVRowEntry *)_rowEntryForItem:(id)fp8 requiredRowEntryLoadMask:(unsigned int)fp12;
- (struct __NSOVRowEntry *)_rowEntryForChild:(int)fp8 ofParent:(struct __NSOVRowEntry *)fp12 requiredRowEntryLoadMask:(unsigned int)fp16;
- (struct __NSOVRowEntry *)_rowEntryForRow:(int)fp8 requiredRowEntryLoadMask:(unsigned int)fp12;
- (id)itemAtRow:(int)fp8;
- (int)rowForItem:(id)fp8;
- (id)parentForItem:(id)fp8;
- (int)levelForItem:(id)fp8;
- (int)levelForRow:(int)fp8;
- (BOOL)isItemExpanded:(id)fp8;
- (BOOL)_userCanEditTableColumn:(id)fp8 row:(int)fp12;
- (BOOL)autosaveExpandedItems;
- (void)setAutosaveExpandedItems:(BOOL)fp8;
- (void)_readPersistentExpandItems;
- (id)_convertPersistentItem:(id)fp8;
- (void)_writePersistentExpandItems;
- (void)setAutosaveName:(id)fp8;
- (BOOL)_shouldAttemptDroppingAsChildOfLeafItems;
- (BOOL)shouldCollapseAutoExpandedItemsForDeposited:(BOOL)fp8;
- (void)setDropItem:(id)fp8 dropChildIndex:(int)fp12;
- (BOOL)_hoverAreaIsSameAsLast:(id)fp8;
- (void)_tryDrop:(id)fp8 dropItem:(id)fp12 dropChildIndex:(int)fp16;
- (void)_determineDropCandidateForDragInfo:(id)fp8;
- (void)_setNeedsDisplayForDropCandidateItem:(id)fp8 childIndex:(int)fp12 mask:(unsigned int)fp16;
- (void)dragImage:(id)fp8 at:(struct _NSPoint)fp12 offset:(struct _NSSize)fp20 event:(id)fp28 pasteboard:(id)fp32 source:(id)fp36 slideBack:(BOOL)fp40;
- (struct _NSRange)_columnRangeForDragImage;
- (void)_drawDropHighlight;
- (BOOL)_canInitiateRowDragInColumn:(int)fp8;
- (void)_sendDelegateDidMouseDownInHeader:(int)fp8;
- (void)_sendDelegateDidClickColumn:(int)fp8;
- (void)_sendDelegateDidDragColumn:(int)fp8;
- (BOOL)_sendDataSourceWriteDragDataWithIndexes:(id)fp8 toPasteboard:(id)fp12;
- (BOOL)_dataSourceRespondsToWriteDragData;
- (void)_sendDataSourceSortDescriptorsDidChange:(id)fp8;
- (BOOL)_dataSourceRespondsToSortDescriptorsDidChange;
- (unsigned int)draggingEntered:(id)fp8;
- (unsigned int)draggingUpdated:(id)fp8;
- (void)draggingExited:(id)fp8;
- (BOOL)performDragOperation:(id)fp8;
- (id)namesOfPromisedFilesDroppedAtDestination:(id)fp8;
- (void)_startAutoExpandingItemFlash;
- (void)_autoExpandFlashOnce;
- (void)_stopAutoExpandingItemFlash;
- (void)_scheduleAutoExpandTimerForItem:(id)fp8;
- (void)_autoExpandItem:(id)fp8;
- (void)_cancelAutoExpandTimer;
- (void)_collapseAllAutoExpandedItems;
- (void)_cancelAnyScheduledAutoCollapse;
- (void)_collapseAutoExpandedItems:(id)fp8;
- (id)_itemsFromRowsWithIndexes:(id)fp8;
- (float)_minXLocOfOutlineColumn;
- (int)_countDisplayedDescendantsOfItem:(id)fp8;
- (id)_findParentWithLevel:(int)fp8 beginingAtItem:(id)fp12 childEncountered:(int *)fp16;
- (void)_verifySelectionIsOK;

@end


@interface GIOutlineViewWithKeyboardSupport : NSOutlineView 
{
    BOOL highlightThreads;
}

@end

@interface GIOutlineViewWithKeyboardSupport (Stripes)

- (BOOL) highlightThreads;
- (void) setHighlightThreads:(BOOL)aBool;

@end

@interface NSOutlineView (RowSelection)

- (int) rowForItemEqualTo: (id) item
            startingAtRow: (int) start;

- (NSArray*) selectedItems;
- (void) selectItems: (NSArray*) items ordered: (BOOL) ordered;

@end