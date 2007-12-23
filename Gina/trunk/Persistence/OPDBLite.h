//
//  OPDBLite.h
//  BTreeLite
//
//  Created by Dirk Theisen on 12.10.07.
//  Copyright 2007 Dirk Theisen. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "sqliteInt.h"
#include "btreeInt.h"

@class OPBTree;
@class OPBTreeCursor;


@interface OPDBLite : NSObject {
	char reserved[sizeof(struct Btree)+4];
	NSMapTable* trees; // keys are tree roots (int), values OPBTree objects
	OPBTree* objectTree; // keys are 64bit OIDs, values are blobs
	OPBTree* treeDescriptionTree; // keys are root page numbers, values are binary plist blobs
}

+ (id) databaseFromFile: (NSString*) filePath 
				  flags: (int) flags
				  error: (int*) error;

- (int) createBTreeWithFlags: (int) flags
					treeRoot: (int*) root;

- (OPBTree*) treeWithRootPage: (int) rootPage;

- (int) beginTransaction;
- (int) commitTransaction;
- (int) rollbackTransaction;
- (BOOL) isInTransaction;

- (OPBTree*) objectTree;

- (id) plistForOid: (u64) oid error: (int*) errorCode;
- (void) setPlist: (id) plist forOid: (u64) oid error: (int*) errorCode;

- (void) unregisterTree: (OPBTree*) tree;
- (void) registerTree: (OPBTree*) tree;

@end

@interface OPBTree : NSObject {
	OPDBLite* db;
	int (*keyCompareFunction)(void*,int,const void*,int,const void*); /* Key Comparison func */
	int rootPage;
	NSString* keyCompareFunctionName;
}

@property (copy) NSString* keyCompareFunctionName;
@property (readonly) int rootPage;

+ (int (*)(void*,int,const void*,int,const void*)) keyCompareFunctionForKey: (NSString*) name;
+ (void) setKeyCompareFunktion: (int (*)(void*,int,const void*,int,const void*)) function forKey: (NSString*) name;

+ (Class) cursorClass;

- (id) initWithCompareFunctionName: (NSString*) functionName
						  withRoot: (int) root
						inDatabase: (OPDBLite*) aDB
							 flags: (int) treeFlags;

- (id) newCursorWithError: (int*) error;


- (NSUInteger) entryCount;


@end

@interface OPIntKeyBTree : OPBTree {
}

- (id) initWithRoot: (int) root
		 inDatabase: (OPDBLite*) aDB;

@end

@interface OPKeyOnlyBTree : OPBTree {
}

- (id) initWithCompareFunctionName: (NSString*) compareFunctionName
						  withRoot: (int) root
						inDatabase: (OPDBLite*) aDB;

@end


/*" Toll free bridged to BtCursor. "*/
@interface OPBTreeCursor : NSObject {
	char* reserved[sizeof(struct BtCursor)+4];
}

- (BOOL) isValid;

- (int (*) (void*,int,const void*,int,const void*)) compareFunction;

- (int) moveToKeyBytes: (const void*) key length: (i64) keyLength error: (int*) error;

- (int) moveToFirst;
- (int) moveToLast;
- (BOOL) moveToNext;
- (BOOL) moveToPrevious;
- (BOOL) eof;

- (int) deleteCurrentEntry;

- (i64) currentEntryIntValue;
- (id) currentEntryPlistValue;
- (NSString*) currentEntryStringValue;
- (void) appendCurrentEntryValueToData: (NSMutableData*) data;

- (i64) currentEntryKeyLengthError: (int*) error;
- (int) getCurrentEntryKeyBytes: (void*) bytes length: (i64) length offset: (u32) offset;
- (int) insertValueBytes: (const void*) data 
				ofLength: (unsigned) dataLength 
			 forKeyBytes: (const void*) key 
				ofLength: (unsigned) keyLength
				isAppend: (BOOL) append;

@end

@interface OPIntKeyBTreeCursor : OPBTreeCursor

- (int) appendEntryValueForIntKey: (i64) key toData: (NSMutableData*) data;
- (i64) currentEntryIntKey;
- (int) moveToIntKey: (i64) key error: (int*) error;

- (int) insertIntValue: (i64) data 
			 forIntKey: (i64) key 
			  isAppend: (BOOL) append;

- (int) insertValueBytes: (const char*) data 
				ofLength: (unsigned) dataLength 
			   forIntKey: (i64) key 
				isAppend: (BOOL) append;

- (int) insertPlistValue: (id) plist
			   forIntKey: (i64) key;

@end


