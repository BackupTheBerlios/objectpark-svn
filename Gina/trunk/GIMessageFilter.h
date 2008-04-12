//
//  GIMessageFilter.h
//  Gina
//
//  Created by Axel Katerbau on 21.12.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OPPersistentObject.h"

@class GIMessage;
@class GIMessageGroup;

@interface GIMessageFilter : OPPersistentObject 
{
	@private
	NSString *name;
	NSPredicate *predicate;
	BOOL performActionPutInMessageGroup;
	OID putInMessageGroupOID;
	BOOL performActionMarkAsSpam;
	BOOL performActionPreventFurtherFiltering;
}

@property (copy) NSString *name;
@property (copy) NSPredicate *predicate;
@property BOOL performActionPutInMessageGroup;
@property (assign) GIMessageGroup *putInMessageGroup;
@property BOOL performActionMarkAsSpam;
@property BOOL performActionPreventFurtherFiltering;

+ (NSMutableArray *)filters;
+ (void)setFilters:(NSMutableArray *)someFilters;
+ (void)saveFilters;

+ (NSArray *)filtersMatchingForMessage:(id)message;
+ (BOOL)applyFiltersToMessage:(GIMessage *)message;
+ (void)applyFiltersToThreads:(id <NSFastEnumeration>)someThreads inGroup:(GIMessageGroup *)aGroup;

@end
