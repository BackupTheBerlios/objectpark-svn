//---------------------------------------------------------------------------------------
//  NSArray+Extensions.h created by erik on Thu 28-Mar-1996
//  @(#)$Id: NSArray+Extensions.h,v 1.1 2004/12/23 16:45:15 theisen Exp $
//
//  Copyright (c) 1996,1999 by Erik Doernenburg. All rights reserved.
//
//  Permission to use, copy, modify and distribute this software and its documentation
//  is hereby granted, provided that both the copyright notice and this permission
//  notice appear in all copies of the software, derivative works or modified versions,
//  and any portions thereof, and that both notices appear in supporting documentation,
//  and that credit is given to Erik Doernenburg in all documents and publicity
//  pertaining to direct or indirect use of this code or its derivatives.
//
//  THIS IS EXPERIMENTAL SOFTWARE AND IT IS KNOWN TO HAVE BUGS, SOME OF WHICH MAY HAVE
//  SERIOUS CONSEQUENCES. THE COPYRIGHT HOLDER ALLOWS FREE USE OF THIS SOFTWARE IN ITS
//  "AS IS" CONDITION. THE COPYRIGHT HOLDER DISCLAIMS ANY LIABILITY OF ANY KIND FOR ANY
//  DAMAGES WHATSOEVER RESULTING DIRECTLY OR INDIRECTLY FROM THE USE OF THIS SOFTWARE
//  OR OF ANY DERIVATIVE WORK.
//---------------------------------------------------------------------------------------


#import <Foundation/NSArray.h>

/*" Various common extensions to #NSArray. "*/

@interface NSArray (OPExtensions)

/*" Retrieving individual objects "*/
- (id)singleObject;
- (id)firstObject;
#ifndef EDCOMMON_OSXBUILD
#ifdef __MACH__
//+ (void) applyFirstObjectPatch;
#endif
#endif

/*" Handling subarrays "*/
- (NSArray*) subarrayToIndex:(unsigned int)index;
- (NSArray*) subarrayFromIndex:(unsigned int)index;

- (BOOL)isSubarrayOfArray:(NSArray*) other atOffset:(int)offset;
- (unsigned int)indexOfSubarray:(NSArray*) other;

/*" Rearranging the array "*/
- (NSArray*) reversedArray;
- (NSArray*) shuffledArray;
- (NSArray*) sortedArray;
- (NSArray*) sortedArrayByComparingAttribute: (NSString*) attributeName;

- (NSArray*) flattenedArray;

- (NSArray*) arrayByRemovingDuplicates;

/*" Mapping the array "*/
- (NSArray*) arrayByMappingWithDictionary: (NSDictionary*) mapping;
- (NSArray*) arrayByMappingWithSelector:(SEL)selector; // similar to valueForKey:
- (NSArray*) arrayByMappingWithSelector:(SEL)selector withObject:(id)object;

/*" List files "*/
+ (NSArray*) librarySearchPaths;
+ (NSArray*) arrayWithFilesOfType: (NSString*) type inPath: (NSString*) aPath;
+ (NSArray*) arrayWithFilesOfType: (NSString*) type inLibrary: (NSString*) libraryName;

@end


/*" Various common extensions to #NSMutableArray. "*/

@interface NSMutableArray (OPExtensions)

- (void) removeDuplicates;

/*" Rearranging the array "*/
- (void) shuffle;
- (void) sort;
- (void) sortByComparingAttribute: (NSString*) attributeName;

// Stack methods:
- (void) pushObject: (id) obj;
- (id) popObject;

@end

