//
//  OPPersistentStringDictionary.h
//  PersistenceKit-Test
//
//  Created by Dirk Theisen on 18.12.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import "OPPersistentObject.h"
#import "OPDBLite.h"

@interface OPPersistentStringDictionary : NSMutableDictionary <OPPersisting> {
	OPBTree* btree;
	OPBTreeCursor* setterCursor;
	NSUInteger count;
	OID oid;
	
@public 
	NSUInteger changeCount; // increased on every add/remove; do not change from outside

}

- (OPPersistentObjectContext*) objectContext;

- (OID) oid;

- (OID) currentOID; // internal method
- (void) setOID: (OID) theOID; // for internal use

@end

