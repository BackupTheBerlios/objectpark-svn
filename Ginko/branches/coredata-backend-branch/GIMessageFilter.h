/*
 $Id: GIMessageFilter.h,v 1.5 2005/05/06 09:03:22 mikesch Exp $

 Copyright (c) 2002, 2003 by Axel Katerbau. All rights reserved.

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
 at http://www.objectpark.org/Ginko.html
 */

#import <Foundation/Foundation.h>
#import <G3Message.h>
#import "GIMessageFilterExpression.h"

@interface GIMessageFilter : NSObject
{
    @private NSMutableDictionary *_filterDefinition;		/*" a dictionary that defines the filter "*/
    @private int _isActiveCache;				/*" a cache for active status (efficiency). "*/
    @private int _allExpressionsMustMatchCache;			/*" a cache for matching mode (efficiency). "*/
    @private NSArray *_actionsCache; 				/*" a cache for the actions (efficiency). "*/
    @private NSArray *_expressionsCache;			/*" a cache for the expressions (efficiency). "*/
}

/*" Initialization "*/
- (id)init;
- (id)initWithFilterDefinitionDictionary:(NSDictionary *)aDictionary;

/*" Accessors "*/
- (NSDictionary *)filterDefinitionDictionary;

- (NSString *)name;
- (void)setName:(NSString *)aName;

- (BOOL)isActive;
- (void)setIsActive:(BOOL)aBool;

- (NSDate *)lastUsed;
- (void)setLastUsed:(NSDate *)aDate;

- (BOOL)allExpressionsMustMatch;
- (void)setAllExpressionsMustMatch:(BOOL)aBool;

- (NSArray *)expressions;
- (void)setExpressions:(NSArray *)someExpressions;

- (NSArray *)actions;
- (void)setActions:(NSArray *)someActions;

/*" Filtering "*/
- (BOOL)matchesForMessage:(G3Message *)message flags:(int)flags;

	/*" Accessors "*/
+ (NSArray *)filters;

	/*" Filter list manipulation "*/
+ (void)moveFilter:(id)filter toIndex:(int)newIndex;
+ (void)insertFilter:(id)filter atPosition:(int)anIndex;
+ (void)removeFilterAtPosition:(int)anIndex;

	/*" Persistence "*/
+ (BOOL)writeFilters;

	/*" Filtering "*/
+ (NSArray *)filtersMatchingForMessage:(G3Message *)message flags:(int)flags;
+ (BOOL)filterMessage:(G3Message *)message flags:(int)flags;

extern NSString *GIMessageFiltersDidChangeNotification;
/*" Informs that a change in the filter set has occurred. The notification object may be a
GIMessageFilterCenter, a GIMessageFilterExpression or a GIMessageFilterAction. No userInfo
provided. "*/

@end
