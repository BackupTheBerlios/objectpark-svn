//
//  OPOutlineViewController.h
//  PersistenceKit-Test
//
//  Created by Dirk Theisen on 21.11.07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/*" This class is used in Ginko to excapsulate some needed behaviour to make the outline view happy. OutlineViews do not retain their data and nor does the model as it relies on oids and the cache for unchanged objects. So there is a chance of unchanged objects being deallocated but still referenced by the outline view. It implements the outlineView dataSource protocol. 
    This implementation requires the tableColumn identifiers to be valid item (KVC) keys.
 
 "*/

@interface OPOutlineViewController : NSObject {
	IBOutlet NSOutlineView* outlineView;
	NSMutableSet* knownItems; // used to keep track of the observed items and to retain them
	NSString* childKey;
	id rootItem;
}

@property (copy) NSString* childKey;
@property (retain) id rootItem;
@property (retain, readonly) NSSet* knownItems;

- (NSArray *)selectedObjects;

@end
