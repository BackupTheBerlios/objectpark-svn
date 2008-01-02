//
//  OPDBLite.m
//  BTreeLite
//
//  Created by Dirk Theisen on 12.10.07.
//  Copyright 2007 Dirk Theisen. All rights reserved.
//

#import "OPDBLite.h"
#import <Foundation/NSDebug.h>


@implementation OPDBLite

#define DBMETA_FREEPAGECOUNT    0
#define DBMETA_OBJECT_TREE_ROOT 1
#define DBMETA_TREE_TREE_ROOT   2

- (u32) metaValueAtIndex: (unsigned short) index
{
	NSParameterAssert(index<=15);
	u32 result = 0;
	int rc = sqlite3BtreeGetMeta((Btree*)self, index, &result);
	NSAssert(rc == SQLITE_OK, @"Unable to get meta data - lock required.");
	return result;
}

- (int) setMetaValue: (u32) value atIndex: (unsigned short) index
{
	NSParameterAssert(index<=15);
	NSParameterAssert(index>0);
	u32 result = 0;
	int rc = sqlite3BtreeUpdateMeta((Btree*)self, index, value);
	NSAssert(rc == SQLITE_OK, @"Unable to write meta data - lock required.");	
	return result;
}


//- (OPBTreeCursor*) newObjectTreeCursor 
//{
//	int error = 0;
//	return [self newCursorForBTreeRoot: [self objectTreeRoot] compare: NULL error: &error];
//}


+ (id) databaseFromFile: (NSString*) filePath 
				  flags: (int) flags
				  error: (int*) error
{
	Btree* btree = NULL;
	int rc;
	if (!error) error = &rc;
	*error = sqlite3BtreeOpen([filePath UTF8String], NULL, &btree, flags, sizeof(OPDBLite)-sizeof(Btree));
	if (*error != SQLITE_OK) {
		return nil;
	}
	btree->objcSupport = self;
	return [(id)btree init];
	
	sizeof(OPDBLite);
}


- (id) createCoreTreeOfType: (int) type
{
	NSParameterAssert(type<=15 && type>0);
	// Create object btree:
	int treeRoot = [self metaValueAtIndex: type];
	if (! treeRoot) [self beginTransaction];
	id tree = [[OPIntKeyBTree alloc] initWithCompareFunctionName: NULL 
														withRoot: treeRoot 
													  inDatabase: self
														   flags: BTREE_INTKEY|BTREE_LEAFDATA];
	
	if (tree && ! treeRoot) {
		[self setMetaValue: [tree rootPage] atIndex: type];
	}
	if (! treeRoot) [self commitTransaction];	
	return tree;
}
	

- (id) init
{
	// Init all variables, they are not nulled automatically!
	objectTree = nil; // important
	treeDescriptionTree = nil; // important
	objectTree = [self createCoreTreeOfType: DBMETA_OBJECT_TREE_ROOT];
	treeDescriptionTree = [self createCoreTreeOfType: DBMETA_TREE_TREE_ROOT];

	// initialize hashmap of btree indexes:
	trees = NSCreateMapTable(NSIntegerMapKeyCallBacks, NSNonRetainedObjectMapValueCallBacks, 15);
	return self;
}

- (NSString*) path
{
	return [NSString stringWithUTF8String: sqlite3PagerFilename(((Btree*)self)->pBt->pPager)];
}

- (NSString*) description
{
	return [NSString stringWithFormat: @"%@ at '%@'", [super description], [self path]];
}

- (OPBTree*) objectTree
{
	return objectTree;
}

- (id) plistForOid: (u64) oid error: (int*) errorCode
{
	int dummy; if (!errorCode) errorCode = &dummy;
	id result = nil;
	int searchResult = 0;
	OPIntKeyBTreeCursor* cursor = [[self objectTree] newCursorWithError: errorCode];
	searchResult = [cursor moveToIntKey: oid error: NULL];
	if (searchResult == 0) {
		result = [cursor currentEntryPlistValue];
	}
	[cursor release];
	return result;
}

- (void) setPlist: (id) plist forOid: (u64) oid error: (int*) errorCode
{
	int dummy; if (!errorCode) errorCode = &dummy;
	OPIntKeyBTreeCursor* cursor = [[self objectTree] newCursorWithError: errorCode];
	NSString* error = nil;
	NSData* plistData = [NSPropertyListSerialization dataFromPropertyList: plist 
																   format: NSPropertyListBinaryFormat_v1_0 
														 errorDescription: &error];
	*errorCode = [cursor insertValueBytes: [plistData bytes] ofLength: [plistData length] forIntKey: oid isAppend: NO];
}

/*" 
 returns < 0    The cursor is left pointing at an entry that
 is smaller than pKey or if the table is empty
 and the cursor is therefore left point to nothing.
 
 returns == 0   The cursor is left pointing at an entry that
 exactly matches pKey.
 
 returns > 0    The cursor is left pointing at an entry that
 is larger than pKey.
 "*/
- (int) moveToKey: (i64) key length: (NSUInteger) keyLength error: (int*) error
{
	int result = 0;
	int dummy; if (!error) error = &dummy;
	*error = sqlite3BtreeMoveto((BtCursor*) self, NULL, key, YES, &result); /* Search result flag */
	if (NSDebugEnabled) { 
		if (result == 0) {
			NSLog(@"Found: entry for key: %016llx", key);
		} else {
			NSLog(@"NOT Found: entry for key: %016llx", key);
		}
	}
	return result;
}



- (OPBTree*) treeDescriptionTree
{
	return treeDescriptionTree;
}

- (int) beginTransaction
{
	return sqlite3BtreeBeginTrans((Btree*) self, 1);
}

- (int) commitTransaction
{
	return sqlite3BtreeCommit((Btree*) self);
}

- (int) rollbackTransaction
{
	return sqlite3BtreeRollback((Btree*) self);
}

- (BOOL) isInTransaction
{
	return sqlite3BtreeIsInTrans((Btree*) self);	
}


/*" Returns the tree root in *root. Returns an error code or SQLITE_OK. "*/
- (int) createBTreeWithFlags: (int) flags
					treeRoot: (int*) root
{
	int result = sqlite3BtreeCreateTable((Btree*)self, root, flags);
	return result;
}


- (void) unregisterTree: (OPBTree*) tree
{
	NSMapRemove(trees, (void*)[tree rootPage]);
}

- (void) registerTree: (OPBTree*) tree
{
	NSMapInsert(trees, (void*)[tree rootPage], tree);
}



- (OPBTree*) treeWithRootPage: (int) rootPage
{	
	OPBTree* result = nil;
	
	result = NSMapGet(trees, (void*) rootPage);
	
	if (!result) {
		NSMutableDictionary* dict = nil; 
		// lookup oid in oid btree:
		OPIntKeyBTreeCursor* cursor = [[self treeDescriptionTree] newCursorWithError: NULL];
		// get plist:
		int error = SQLITE_OK;
		if ([cursor moveToIntKey: rootPage error: &error] && error==SQLITE_OK) {
			
			dict = [cursor currentEntryPlistValue];
			
			// extract flags, compareFunction#, rootPage
			Class treeClass = NSClassFromString([dict objectForKey: @"class"]);
			//int (*keyCompareFunction)(void*,int,const void*,int,const void*) = NULL; /* Key Comparison func */
			int flags = [[dict objectForKey: @"flags"] intValue];
			int root = [[dict objectForKey: @"rootPage"] intValue];
			
			result = [[[treeClass alloc] initWithCompareFunctionName: nil
															withRoot: root
														  inDatabase: self
															   flags: flags] autorelease];
			[self registerTree: result];
		}
		[cursor release];
	}
	return result;
}

+ (id) alloc
{
	NSParameterAssert(NO);
	return nil;
}

- (void) dealloc
{
	[objectTree release];
	sqlite3BtreeClose((Btree*) self); // releases, nulls the memory
	// no missing dealloc call!
}


@end


@implementation OPBTree 

+ (Class) cursorClass
{
	return [OPBTreeCursor class];
}

+ (NSMapTable*) compareFunctions
{
	static NSMapTable* compareFunctions = nil;
	if (! compareFunctions) {
		compareFunctions = [[NSMapTable alloc] initWithKeyPointerFunctions: [NSPointerFunctions pointerFunctionsWithOptions: NSPointerFunctionsObjectPersonality]
													 valuePointerFunctions: [NSPointerFunctions pointerFunctionsWithOptions: NSPointerFunctionsOpaquePersonality] 
																  capacity: 5];
	}
	return compareFunctions;
}


+ (int (*)(void*,int,const void*,int,const void*)) keyCompareFunctionForKey: (NSString*) name
{
	return NSMapGet([self compareFunctions], name);
}

+ (void) setKeyCompareFunktion: (int (*)(void*,int,const void*,int,const void*)) function forKey: (NSString*) name
{
	NSMapInsert([self compareFunctions], name, function);
}

- (NSString*) keyCompareFunctionName
{
	return keyCompareFunctionName;
}

- (void) setKeyCompareFunctionName: (NSString*) functionName
{
	if (! (functionName == keyCompareFunctionName || [functionName isEqualToString: keyCompareFunctionName])) {
		NSAssert([self entryCount] == 0, @"The keyCompareFunctionName can only be set on an empty btree.");
		[keyCompareFunctionName release];
		keyCompareFunctionName = [functionName copy];
		keyCompareFunction = [OPBTree keyCompareFunctionForKey: [self keyCompareFunctionName]];
	}
}

/*" A zero root allocates a new tree (root). "*/
- (id) initWithCompareFunctionName: (NSString*) functionName
						  withRoot: (int) root
						inDatabase: (OPDBLite*) aDB
							 flags: (int) treeFlags
/*
** The type of type is determined by the flags parameter.  Only the
** following values of flags are currently in use.  Other values for
** flags might not work:
**
**     BTREE_INTKEY|BTREE_LEAFDATA     Used for SQL tables with rowid keys
**     BTREE_ZERODATA                  Used for SQL indices
*/
{
	if (self = [super init]) {
		BOOL createTree = (root == 0);
		
		if (createTree) {
			int result = sqlite3BtreeCreateTable((Btree*)aDB, &root, treeFlags);
			if (result != SQLITE_OK) {
				sqlite3BtreeCreateTable((Btree*)aDB, &root, treeFlags);
				[self autorelease];
				return nil;
			}
		}
		
		[self setKeyCompareFunctionName: functionName]; // do this before setting rootPage
		rootPage = root;
		db = [aDB retain];
		keyCompareFunction = [[self class] keyCompareFunctionForKey: functionName];
	}
	return self;
}

 
- (int) rootPage
{
	return rootPage;
}

/*" Deletes the current btree from the DB. "*/
- (int) delete
{
	int newRoot = 0;
	return sqlite3BtreeDropTable((Btree*) db, [self rootPage], &newRoot);
}


//int sqlite3BtreeClearTable(Btree*, int);

- (NSUInteger) entryCount
/*" Walks through all the entries and returns the count. "*/
{
	NSUInteger result = 0;
	int error;
	OPBTreeCursor* cursor = [self newCursorWithError: &error];
	if (cursor) {
		if ([cursor moveToFirst] == SQLITE_OK) {
			result = 1;
			while ([cursor moveToNext]) result++;
		}
		NSAssert([cursor eof], @"Cursor not at EOF after counting entries.");
	}
	[cursor release];

	return result;
}


- (void) dealloc
{
	[keyCompareFunctionName release];
	[db unregisterTree: self];
	[super dealloc];
}


- (id) newCursorWithError: (int*) error
{
	BtCursor* result = NULL;
	if (rootPage) {
		BOOL readwrite = YES;
		int dummyError; if (!error) error = &dummyError;
		Class cursorClass = [[self class] cursorClass];
		
		*error = sqlite3BtreeCursor((Btree*) db, [self rootPage], readwrite, keyCompareFunction, self, sizeof(OPBTreeCursor)-sizeof(BtCursor), &result);
		if (*error != SQLITE_OK) {
			return nil;
		}
		result->objcSupport = cursorClass; // set isa pointer
		//NSLog(@"Creating Cursor of class %@", cursorClass);
	}
	return [(id)result init];
}


@end

@implementation OPIntKeyBTree  

+ (Class) cursorClass
{
	return [OPIntKeyBTreeCursor class];
}

- (id) initWithRoot: (int) root
		 inDatabase: (OPDBLite*) aDB
{
	return [super initWithCompareFunctionName: NULL 
									 withRoot: root 
								   inDatabase: aDB 
										flags: BTREE_INTKEY|BTREE_LEAFDATA];
}

@end

@implementation OPKeyOnlyBTree  
/*" All data is stored in the keys. "*/

+ (Class) cursorClass
{
	return [OPBTreeCursor class];
}

- (id) initWithCompareFunctionName: (NSString*) compareFunctionName
						  withRoot: (int) root
						inDatabase: (OPDBLite*) aDB
{
	return [super initWithCompareFunctionName: compareFunctionName
									 withRoot: root 
								   inDatabase: aDB 
										flags:BTREE_ZERODATA];
}

@end

@implementation OPBTreeCursor 


#define isSelfValid (((BtCursor*) self)->eState == CURSOR_VALID)

/*
 ** Delete the entry that the cursor is pointing to.  The cursor
 ** is left pointing at a random location.
 */
- (int) deleteCurrentEntry 
{
	return sqlite3BtreeDelete((BtCursor*) self);
}

- (BOOL) isValid
{
	return isSelfValid;
}

- (int (*) (void*,int,const void*,int,const void*)) compareFunction
{
	return ((BtCursor*) self)->xCompare;
}


/*" Returns YES, if the cursor was successfully moved. "*/
- (BOOL) moveToNext
{
	int eof = YES;
	int rc = sqlite3BtreeNext((BtCursor*) self, &eof);
	NSAssert1(rc == SQLITE_OK, @"Moving cursor to next entry failed with return code %d", rc);

	return eof == NO;
}

/*" Returns YES, if the cursor was successfully moved. "*/
- (BOOL) moveToPrevious
{
	int eof = YES;
	int rc = sqlite3BtreePrevious((BtCursor*) self, &eof);
	NSAssert1(rc == SQLITE_OK, @"Moving cursor to next entry failed with return code %d", rc);
	
	return eof == NO;
}




- (BOOL) eof
{
	return sqlite3BtreeEof((BtCursor*) self);
}

- (NSString*) currentEntryStringValue
{
	NSString* result = nil;
	u32 dataSize = 0;
	int rc = sqlite3BtreeDataSize((BtCursor*) self, &dataSize);
	if (rc == SQLITE_OK) {
		void* bytes = malloc(dataSize);
		if (bytes) {
			rc = sqlite3BtreeData((BtCursor*) self, 0, dataSize, bytes);
			if (rc == SQLITE_OK) {
				result = [[[NSString alloc] initWithBytesNoCopy: bytes length: dataSize encoding:NSUTF8StringEncoding freeWhenDone: YES] autorelease];
			}
		}
	}
	return result;
}

- (i64) currentEntryIntValue
{
	i64 result = 0;
	int rc = sqlite3BtreeData((BtCursor*) self, 0, sizeof(result), &result);
	NSAssert1(rc == SQLITE_OK, @"Getting int data failed with return code %d", rc);
	result = NSSwapLittleLongLongToHost(result);
	return result;
}

- (i64) currentEntryKeyLengthError: (int*) error
{
	i64 result = 0;
	int err = 0;
	if (!error) error = &err;
	*error = sqlite3BtreeKeySize((BtCursor*) self, &result);
	return result;
}

- (int) getCurrentEntryKeyBytes: (void*) bytes length: (i64) length offset: (u32) offset
{
	int rc = sqlite3BtreeKey((BtCursor*) self, offset, length, bytes);
	return rc;
}


- (void) appendCurrentEntryValueToData: (NSMutableData*) data
{
	unsigned oldLength = [data length];
	u32 size = 0;
	int rc = sqlite3BtreeDataSize((BtCursor*) self, &size);
	NSAssert1(rc == SQLITE_OK, @"Getting value data size failed with return code %d", rc);
	[data setLength: oldLength+size];
	rc = sqlite3BtreeData((BtCursor*) self, 0, size, ((char*)[data mutableBytes])+oldLength);
	NSAssert1(rc == SQLITE_OK, @"Getting value data failed with return code %d", rc);
}


- (id) currentEntryPlistValue
{
	NSMutableData* data = [[NSMutableData alloc] init];
	NSString* error = nil;
	[self appendCurrentEntryValueToData: data];
	id result = [NSPropertyListSerialization propertyListFromData: data 
												 mutabilityOption: NSPropertyListMutableContainers  
														   format: NULL 
												 errorDescription: &error];
	[data release];
	return result;
}



- (int) insertValueBytes: (const void*) data 
				ofLength: (unsigned) dataLength 
		  forKeyBytes: (const void*) key 
				ofLength: (unsigned) keyLength
				isAppend: (BOOL) append
{
	int err = sqlite3BtreeInsert((BtCursor*) self, /* Insert data into the table of this cursor */
								 key, keyLength,   /* The key of the new record */
								 data, dataLength, /* The data of the new record */
								 0,                /* Number of extra 0 bytes to append to data */
								 append);          /* True if this is likely an append */
	return err;
}


- (void) dealloc
{
	int error = sqlite3BtreeCloseCursor((BtCursor*) self);
	NSAssert(error == SQLITE_OK, @"unable to close cursor.");
	// no missing dealloc call
}

- (int) moveToLast
/*"  on error, returns an error code. Returns 0, if the cursor afterwards points to the last element, 1 if no such element exists. "*/
{
	int pRes;
	int rc = sqlite3BtreeLast((BtCursor*) self, &pRes);	
	return rc == 0 ? pRes : rc;
}

- (int) moveToFirst
/*" on error, returns an error code. Returns 0, if the cursor afterwards points to the first element, 1 if no such element exists. "*/
{
	int pRes;
	int rc = sqlite3BtreeFirst((BtCursor*) self, &pRes);	
	return rc == 0 ? pRes : rc;
}


/*" 
 returns < 0    The cursor is left pointing at an entry that
 is smaller than pKey or if the table is empty
 and the cursor is therefore left point to nothing.
 
 returns == 0   The cursor is left pointing at an entry that
 exactly matches pKey.
 
 returns > 0    The cursor is left pointing at an entry that
 is larger than pKey.
 "*/
- (int) moveToKeyBytes: (const void*) key length: (i64) keyLength error: (int*) error
{
	int result = 0;
	int dummy; if (!error) error = &dummy;
	*error = sqlite3BtreeMoveto((BtCursor*) self, key, keyLength, YES, &result); /* Search result flag */
	NSLog(@"Seeking in %@", self);
	NSAssert1(*error != 11, @"SQLite: The database disk image is malformed (%@)", self); 

	if (NSDebugEnabled) { 
		if (result == 0) {
			NSLog(@"Found: entry for key: %016llx", key);
		} else {
			NSLog(@"NOT Found: entry for key: %016llx", key);
		}
	}
	return result;
}

- (OPDBLite*) database
{
	return (OPDBLite*)((BtCursor*)self)->pBtree;
}

- (NSString*) description
{
	return [NSString stringWithFormat: @"%@ in %@", [super description], [self database]];
}

@end


@implementation OPIntKeyBTreeCursor


- (i64) currentEntryIntKey
{
	i64 result = 0;
	int rc = sqlite3BtreeKeySize((BtCursor*) self, &result);
	NSAssert1(rc == SQLITE_OK, @"Getting int key failed with return code %d", rc);
	
	return result;
}


/*" 
 returns < 0    The cursor is left pointing at an entry that
 is smaller than pKey or if the table is empty
 and the cursor is therefore left point to nothing.
 
 returns == 0   The cursor is left pointing at an entry that
 exactly matches pKey.
 
 returns > 0    The cursor is left pointing at an entry that
 is larger than pKey.
 "*/
- (int) moveToIntKey: (i64) key error: (int*) error
{
	int result = 0;
	int dummy; if (!error) error = &dummy;
	*error = sqlite3BtreeMoveto((BtCursor*) self, NULL, key, YES, &result); /* Search result flag */
	if (NSDebugEnabled) { 
		if (result == 0) {
			NSLog(@"Found: entry for key: %016llx", key);
		} else {
			NSLog(@"NOT Found: entry for key: %016llx", key);
		}
	}
	return result;
}


- (int) appendEntryValueForIntKey: (i64) key toData: (NSMutableData*) data 
{
	int error = SQLITE_OK;
	int pos = [self moveToIntKey: key error: &error];
	if (pos == 0) {
		[self appendCurrentEntryValueToData: data];
	} else {
		NSLog(@"appendEntryValueForIntKey: toData: failed for key: %016llx", key);
	}
	return error;
}

/*
 ** Insert a new record into the BTree.  The key is given by (pKey,nKey)
 ** and the data is given by (pData,nData).  The cursor is used only to
 ** define what table the record should be inserted into.  The cursor
 ** is left pointing at a random location.
 **
 ** For an INTKEY table, only the nKey value of the key is used.  pKey is
 ** ignored.  For a ZERODATA table, the pData and nData are both ignored.
 */
- (int) insertValueBytes: (const char*) data 
				ofLength: (unsigned) dataLength 
			   forIntKey: (i64) key 
				isAppend: (BOOL) append
{
	if (NSDebugEnabled) NSLog(@"Inserting %u bytes for key: %016llx", dataLength, key);
	int error = sqlite3BtreeInsert((BtCursor*) self, /* Insert data into the table of this cursor */
								   NULL, key,        /* The key of the new record */
								   data, dataLength,  /* The data of the new record */
								   0,                /* Number of extra 0 bytes to append to data */
								   append);          /* True if this is likely an append */
	if (error == SQLITE_OK) {
		int pos = [self moveToIntKey: key error: &error];
		NSAssert(pos==0, @"unable to find inserted key.");
	}
	return error;
}

- (int) insertIntValue: (i64) data 
			 forIntKey: (i64) key 
			  isAppend: (BOOL) append
{
	data = NSSwapHostLongLongToLittle(data);
	return sqlite3BtreeInsert((BtCursor*) self, /* Insert data into the table of this cursor */
							  NULL, key,   /* The key of the new record */
							  &data, sizeof(i64), /* The data of the new record */
							  0,                /* Number of extra 0 bytes to append to data */
							  append);          /* True if this is likely an append */
}

- (int) insertPlistValue: (id) plist
			   forIntKey: (i64) key 
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	NSString* error;
	NSData* data = [NSPropertyListSerialization dataFromPropertyList: plist 
															  format: NSPropertyListBinaryFormat_v1_0 
													errorDescription: &error];
	
	int rc = [self insertValueBytes: [data bytes] ofLength: [data length] forIntKey: key isAppend: NO];
	[pool release];
	return rc;
}


@end

//@implementation OPCWrapper
//
//- (id) retain {return self;}
//- (void) release {}
//- (id) autorelease {return self;}
////- (void) dealloc {};
//
//@end