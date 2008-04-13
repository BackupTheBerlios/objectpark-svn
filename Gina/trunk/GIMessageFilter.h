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
@class OPFaultingArray;

@interface GIMessageFilter : OPPersistentObject 
{
	@private
	NSString *name;
	BOOL enabled;
	NSPredicate *predicate;
	BOOL performActionPutInMessageGroup;
	OID putInMessageGroupOID;
	BOOL performActionMarkAsSpam;
	BOOL performActionPreventFurtherFiltering;
}

@property (copy) NSString *name;
@property BOOL enabled;
@property (retain) NSPredicate *predicate;
@property BOOL performActionPutInMessageGroup;
@property (assign) GIMessageGroup *putInMessageGroup;
@property BOOL performActionMarkAsSpam;
@property BOOL performActionPreventFurtherFiltering;

- (void)performFilterActionsOnMessage:(GIMessage *)message putIntoMessagebox:(BOOL *)putInBox shouldStop:(BOOL *)shouldStop;

+ (NSArray*) filters;

+ (void)applyFiltersToThreads:(id <NSFastEnumeration>)someThreads inGroup:(GIMessageGroup *)aGroup;
+ (BOOL)applyFiltersToMessage:(GIMessage *)message;

@end

//@interface GIMessageFilterList : OPPersistentObject
//{
//	@private
//	//OPFaultingArray *filters;
//}
//
//@property (readonly) OPFaultingArray *filters;
//
//+ (OPFaultingArray *)filters;
//+ (NSArray *)filtersMatchingForMessage:(id)message;
//+ (BOOL)applyFiltersToMessage:(GIMessage *)message;
//+ (void)applyFiltersToThreads:(id <NSFastEnumeration>)someThreads inGroup:(GIMessageGroup *)aGroup;
//
//@end