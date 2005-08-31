/*
 $Id: GIMessageFilterExpression.m,v 1.3 2005/04/25 09:08:28 mikesch Exp $

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

#import "GIMessageFilterExpression.h"
#import "GIMessageFilter.h"
#import "G3Message.h"
#import "OPInternetMessage.h"
#import "EDTextFieldCoder.h"

@implementation GIMessageFilterExpression
/*" Model for an expression of a messge filter. "*/

- (id) initWithExpressionDefinitionDictionary: (NSDictionary*) aDictionary
/*" Initializes the expression with a defining dictionary "*/
{
    [super init];

    _expressionDefinition = [aDictionary mutableCopyWithZone:[self zone]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(filtersDidChange:) name:GIMessageFiltersDidChangeNotification object:self];
    
    return self;
}

- (void) dealloc
/*" Releases ivars. "*/
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_expressionDefinition release];
    [_subjectsCache release]; _subjectsCache = nil;
    [super dealloc];
}

- (NSDictionary*) expressionDefinitionDictionary
/*" Returns the dictionary that defines the receiver. "*/
{
    return _expressionDefinition;
}

- (int) subjectType
{
    return [[_expressionDefinition objectForKey: @"subjectType"] intValue];
}

- (void) setSubjectType: (int) aType
{
    [_expressionDefinition setObject: [NSNumber numberWithInt:aType] forKey: @"subjectType"];

    // model changed
    [[NSNotificationCenter defaultCenter] postNotificationName: GIMessageFiltersDidChangeNotification object:self];
}

- (NSString*) subjectValue
/*" Returns the (simple) receivers's subject (e.g. "To" Header) "*/ 
{
    return [_expressionDefinition objectForKey: @"subjectValue"];
}

- (void) setSubjectValue: (NSString*) aString
/*" Sets the (simple) subject of the receiver (e.g. "To" Header). "*/
{
    [_expressionDefinition setObject: aString ? aString: @"" forKey: @"subjectValue"];
    
    // model changed
    [[NSNotificationCenter defaultCenter] postNotificationName: GIMessageFiltersDidChangeNotification object: self];
}

- (int)criteria
/*" The receiver's filter criteria (see %{GIMessageFilterExpressionCriteria})."*/
{
    return [[_expressionDefinition objectForKey: @"criteria"] intValue];
}

- (void)setCriteria: (int) aCriteria
/*" Sets the receiver's filter criteria (see %{GIMessageFilterExpressionCriteria})."*/
{
    [_expressionDefinition setObject:[NSNumber numberWithInt: aCriteria] forKey:@"criteria"];

    // model changed
    [[NSNotificationCenter defaultCenter] postNotificationName: GIMessageFiltersDidChangeNotification 
														object: self];    
}

- (NSString*) argument
/*" The receiver's filter argument (when subjectType is not kGIMFTypeFlag). "*/
{
    return [_expressionDefinition objectForKey:@"argument"];
}

- (void) setArgument: (NSString*) aString
/*" Sets the receiver's filter argument (when subjectType is not kGIMFTypeFlag). "*/
{
    [_expressionDefinition setObject: aString forKey: @"argument"];

    // model changed
    [[NSNotificationCenter defaultCenter] postNotificationName: GIMessageFiltersDidChangeNotification 
														object: self];
}

- (int) flagArgument
/*" The receiver's flag argument (when subjectType is kGIMFTypeFlag) "*/
{
    return [[_expressionDefinition objectForKey: @"flagArgument"] intValue];
}

- (void) setFlagArgument: (int) flagArgument
/*" Sets the receiver's flag filter argument (when subjectType is kGIMFTypeFlag). "*/
{
    [_expressionDefinition setObject: [NSNumber numberWithInt: flagArgument] forKey: @"flagArgument"];

    // model changed
    [[NSNotificationCenter defaultCenter] postNotificationName:GIMessageFiltersDidChangeNotification object:self];
}

- (void) filtersDidChange: (NSNotification*) aNotification
/*" Cleares the _subjects cache. "*/
{
    [_subjectsCache release];
    _subjectsCache = nil;
}

// matching
- (BOOL)matchesForMessage:(G3Message *)message flags:(int)flags
{
    NSEnumerator *enumerator;
    NSString *matchString, *argument;
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSArray *matchStrings = nil;
    BOOL matches = NO;

    // Step one: assembling of subjects (array of strings)
    switch ([self subjectType]) 
	{
        case kGIMFTypeHeaderField: 
		{
            NSString *header;

            if (! _subjectsCache) 
			{
                _subjectsCache = [[[[self subjectValue] lowercaseString] componentsSeparatedByString:@" or "] retain];
            }

            matchStrings = [[NSMutableArray alloc] initWithCapacity:[_subjectsCache count]];

            enumerator = [_subjectsCache objectEnumerator];
            while (header = [enumerator nextObject]) 
			{
                NSString *fieldBody;

                fieldBody = [[message internetMessage] bodyForHeaderField:header];

                if (fieldBody) 
				{
                    [(NSMutableArray *)matchStrings addObject:[EDTextFieldCoder stringFromFieldBody:fieldBody withFallback:YES]];
                }
            }
            break;
        };
        case kGIMFTypeFlag:
            switch ([self criteria]) 
			{
                case kGIMFCriteriaContains:
                    return ([self flagArgument] & flags) != 0;
                    break;
                case kGIMFCriteriaDoesNotContain:
                    return ([self flagArgument] & flags) == 0;
                    break;
                case kGIMFCriteriaEquals:
                    return [self flagArgument] == flags;
                    break;
                default:
                    return NO;
                    break;
            }
            break;
        default:
            // ## missing code (other subjectTypes)
            NSLog(@"Only kGIMFTypeHeaderField supported right now, sorry.");
            break;
    }
    // Step two: match the match strings
    argument = [self argument];

    if (argument) 
	{
        enumerator = [matchStrings objectEnumerator];
        while ( (matchString = [enumerator nextObject]) &&  (! matches) ) 
		{
            switch ([self criteria]) 
			{
                case kGIMFCriteriaContains: 
				{
                    NSRange foundRange;

                    foundRange = [matchString rangeOfString:argument options:NSCaseInsensitiveSearch range:NSMakeRange(0, [matchString length])];

                    matches = (foundRange.location != NSNotFound) && (foundRange.length != 0);
                    break;
                }
                case kGIMFCriteriaDoesNotContain: 
				{
                    NSRange foundRange;

                    foundRange = [matchString rangeOfString:argument options:NSCaseInsensitiveSearch range:NSMakeRange(0, [matchString length])];

                    matches = (foundRange.location == NSNotFound) && (foundRange.length == 0);
                    break;
                }
                case kGIMFCriteriaStartsWith:
                    matches = [matchString hasPrefix:argument];
                    break;
                case kGIMFCriteriaEndsWith:
                    matches = [matchString hasSuffix:argument];
                    break;
                case kGIMFCriteriaEquals:
                    matches = [matchString caseInsensitiveCompare: argument] == NSOrderedSame;
                    break;
                default:
                    break;
            }
        }
    }
    [matchStrings release];
    [pool release];

    /*
     if (matches)
     {
         MPWDebugLog(@"FilterExpression %@ matches for message %@.", self, [message messageId]);
     }
     */

    return matches;
}

@end
