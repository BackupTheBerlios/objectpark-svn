//
//  OPPersistentStringDictionary.h
//  PersistenceKit-Test
//
//  Created by Dirk Theisen on 18.12.07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "OPPersistentObject.h"
#import "OPDBLite.h"

@interface OPPersistentStringDictionary : NSMutableDictionary <NSCoding> {
	OPBTree* btree;
	OPBTreeCursor* setterCursor;
	NSUInteger count;
}

@end
