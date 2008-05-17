//
//  OPOutlineViewController.h
//  Gina
//
//  Created by Dirk Theisen on 21.11.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/*" This class is used in Gina to excapsulate some needed behaviour to make the outline view happy. OutlineViews do not retain their data and nor does the model as it relies on oids and the cache for unchanged objects. So there is a chance of unchanged objects being deallocated but still referenced by the outline view. It implements the outlineView dataSource protocol. 
    This implementation requires the tableColumn identifiers to be valid item (KVC) keys. 
    Must be delegate and data source of the outline view to control.
 "*/

#import "OPPersistentObject.h"

//@interface OPPersistentObjectReference : NSObject {
//	OID referencedObjectOID; 
//}
//
//- (id) initWithReferencedObjectOID: (OID) oid;
//- (id <OPPersisting>) referencedObject;
//- (OID) referencedObjectOID;
//
//@end

@interface OPOutlineViewController : NSController 
{
	IBOutlet NSOutlineView* outlineView;
	NSMutableSet* knownItems; // used to keep track of the observed items and to retain them
	NSString* childKey;
	NSString* childCountKey;
	id rootItem;
//	NSMutableSet* expandedItems; // unused
	NSMutableArray* selectedItemsPaths;
	
	@private
	id observedObjectForRootItem;
	NSString* observedKeyPathForRootItem;
	id observedObjectForSelectedObjects;
	NSString* observedKeyPathForSelectedObjects;

	BOOL suspendUpdatesUntilNextReloadData;
	BOOL doCalculateSelectedItemPaths;
}

@property BOOL suspendUpdatesUntilNextReloadData;
@property (copy) NSString *childKey;
@property (copy) NSString *childCountKey;
@property (retain) id rootItem;
@property (retain, readonly) NSSet *knownItems;
@property (retain, readwrite) NSOutlineView* outlineView;

- (NSArray*) selectedObjects;
//- (void) setSelectedObjects: (NSArray*) anArray;

//- (void) setSelectedObject: (id) object;
- (id) selectedObject;

- (void) reloadData;

- (NSSet*) keyPathsAffectingDisplayOfItem: (id) item;

- (NSArray*) selectedItemsPaths;
- (void) setSelectedItemsPaths: (NSArray*) itemPaths byExtendingSelection: (BOOL) extend;

- (NSUInteger) rowForItemPath: (NSArray*) path;
- (void) resetKnownItems;

- (void)suspendUpdates;
- (void)resumeUpdates;

- (void)scrollSelectionToVisible;

@end

@interface OPOutlineViewController (ConvenientSlowHelpers)

- (NSArray *)itemPathForItem:(id)item;

@end

@interface NSOutlineView (OPPrivateAPI)
- (void)_expandItemEntry:(struct __NSOVRowEntry *)fp8 expandChildren:(BOOL)fp12;
- (struct __NSOVRowEntry *)_rowEntryForRow:(int)fp8 requiredRowEntryLoadMask:(unsigned int)fp12;
@end

@interface NSOutlineView (OPPrivate)

- (void) expandItemAtRow: (int) row expandChildren: (BOOL) expand;
- (BOOL) isItemExpandedAtRow: (int) row;

@end

