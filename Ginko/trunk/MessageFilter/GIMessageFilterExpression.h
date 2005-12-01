/*
 $Id: GIMessageFilterExpression.h,v 1.2 2005/04/25 09:08:28 mikesch Exp $

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

@class GIMessage;

typedef enum GIMessageFilterExpressionCriteria GIMessageFilterExpressionCriteria;
enum GIMessageFilterExpressionCriteria
{
    kGIMFCriteriaContains = 1,
    kGIMFCriteriaDoesNotContain,
    kGIMFCriteriaStartsWith,
    kGIMFCriteriaEndsWith,
    kGIMFCriteriaEquals
};

typedef enum GIMessageFilterExpressionSubjectType GIMessageFilterExpressionSubjectType;
enum GIMessageFilterExpressionSubjectType
{
    kGIMFTypeHeaderField = 1,
    kGIMFTypeBody,
    kGIMFTypeFlag    
};

@interface GIMessageFilterExpression : NSObject
{
    @private NSMutableDictionary* _expressionDefinition;	/*" a dictionary that defines the expression "*/
    @private NSArray* _subjectsCache;				/*" a cache for the subjects (e.g. ("to", "cc")) "*/
}

/*" Initializers "*/
- (id) initWithExpressionDefinitionDictionary: (NSDictionary*) aDictionary;

/*" Accessors "*/
- (NSDictionary*) expressionDefinitionDictionary;

- (int) subjectType;
- (void) setSubjectType:(int)aType;

- (NSString*) subjectValue;
- (void) setSubjectValue: (NSString*) aString;

- (int) criteria;
- (void) setCriteria: (int) aCriteria;

- (NSString*) argument;
- (void) setArgument: (NSString*) aString;

- (int)flagArgument;
- (void) setFlagArgument:(int)flagArgument;

/*" Matching "*/
- (BOOL)matchesForMessage: (GIMessage*) message flags:(int)flags;

@end
