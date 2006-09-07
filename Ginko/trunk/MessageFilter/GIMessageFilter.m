/*
 $Id: GIMessageFilter.m,v 1.5 2005/05/06 09:03:22 mikesch Exp $

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

#import "GIMessageFilter.h"
#import "GIMessageFilterAction.h"
#import "NSApplication+OPExtensions.h"
#import "EDMessagePart+OPExtensions.h"
#import "OPInternetMessage.h"
#import "GIJunkfilter.h"
#import "OPObjectPair.h"

#define GIMESSAGEFILTER OPL_DOMAIN @"GIMESSAGEFILTER"

NSString *GIMessageFiltersDidChangeNotification = @"GIMessageFiltersDidChangeNotification";
NSString *GIMessageFilterCenterDelayedWriteFilters = @"GIMessageFilterCenterDelayedWriteFilters";

@implementation GIMessageFilter
/*" Not thread safe! "*/

- (void) _setDefaultValues
/*" Initializes cache ivars to 'unknown' state. "*/
{
    _isActiveCache = _allExpressionsMustMatchCache = -1;
    _actionsCache = (id)self;
    _expressionsCache = (id)self;
}

- (id)init
/*" Initializes an empty filter. "*/
{
    [super init];

    _filterDefinition = [[NSMutableDictionary alloc] init];
    [self _setDefaultValues];
    [self setIsActive: YES];
    [self setName:NSLocalizedString(@"New Filter", name of a new filter)];
    
    return self;
}

- (id)initWithFilterDefinitionDictionary: (NSDictionary*) aDictionary
/*" Initializes with the given dictionary. For keys and values see the defines/typedefs/enums. "*/
{
    [super init];

    _filterDefinition = [aDictionary mutableCopy];
    [self _setDefaultValues];
    return self;
}

- (void) dealloc
/*" Releases ivars. "*/
{
    [_filterDefinition release];
    
    if (_actionsCache != (id)self)
    {
        [_actionsCache release];
    }

    if (_expressionsCache != (id)self)
    {
        [_expressionsCache release];
    }
    
    [super dealloc];
}

- (NSDictionary *)filterDefinitionDictionary
/*" Returns the filter definition dictionary of the receiver. "*/
{
    NSMutableArray *actionDefinitions;
    NSMutableArray *expressionDefinitions;
    NSEnumerator *enumerator;
    GIMessageFilterAction *action;
    GIMessageFilterExpression *expression;
    
//    [_filterDefinition setObject: [[self expression] expressionDefinitionDictionary] forKey: @"expression"];

    expressionDefinitions = [[NSMutableArray alloc] initWithCapacity:[[self expressions] count]];

    enumerator = [[self expressions] objectEnumerator];
    while (expression = [enumerator nextObject])
    {
        [expressionDefinitions addObject:[expression expressionDefinitionDictionary]];
    }

    [_filterDefinition setObject: expressionDefinitions forKey: @"expressions"];

    [expressionDefinitions release];
    
    actionDefinitions = [[NSMutableArray alloc] initWithCapacity:[[self actions] count]];

    enumerator = [[self actions] objectEnumerator];
    while (action = [enumerator nextObject])
    {
        [actionDefinitions addObject:[action actionDefinitionDictionary]];
    }

    [_filterDefinition setObject: actionDefinitions forKey: @"actions"];

    [actionDefinitions release];
    
    return _filterDefinition;
}

- (NSMutableDictionary *)_filterDefinition
/*" Returns the filter definition dictionary. "*/
{
    return _filterDefinition;
}

- (NSString*) name
/*" Returns the description of the receiver if given. nil otherwise. "*/
{
    return [_filterDefinition objectForKey: @"name"];
}

- (void) setName: (NSString*) aName
/*" Sets the description of the receiver. "*/
{
    NSParameterAssert(aName != nil);
    [[self _filterDefinition] setObject: aName forKey: @"name"];

    // model changed
    [[NSNotificationCenter defaultCenter] postNotificationName:GIMessageFiltersDidChangeNotification object:self];
}

- (NSDate*) lastUsed
/*" Returns the date of the last use of the receiver. "*/
{
    id lastUsed;

    if (lastUsed = [_filterDefinition objectForKey: @"lastUsed"])
    {
        if (! [lastUsed isKindOfClass:[NSDate class]])
        {
            lastUsed = [[NSDate alloc] initWithString:lastUsed];
            [[self _filterDefinition] setObject: lastUsed forKey: @"lastUsed"];
            [lastUsed release];
        }
    }
    return (NSDate*) lastUsed;
}

- (void) setLastUsed:(NSDate*) aDate
/*" Sets the date of the last use of the receiver. "*/
{
    NSParameterAssert(aDate != nil);
    [[self _filterDefinition] setObject: aDate forKey: @"lastUsed"];

    // model changed
    [[NSNotificationCenter defaultCenter] postNotificationName:GIMessageFiltersDidChangeNotification object:self];
}

- (GIMessageFilterExpression *)_expression
/*" Returns the matching expression of the receiver. "*/
{
    NSDictionary *expressionDefinition;
    GIMessageFilterExpression *result = nil;

    if ((expressionDefinition = [_filterDefinition objectForKey: @"expression"]))
    {
        result = [[[GIMessageFilterExpression alloc] initWithExpressionDefinitionDictionary:expressionDefinition] autorelease];
    }
    
    return result;
}

- (void) _setExpression: (GIMessageFilterExpression*) anExpression
/*" Sets the expression of the receiver. "*/
{
    NSParameterAssert(anExpression == nil);
    [[self _filterDefinition] removeObjectForKey: @"expression"];
}

- (NSArray*) actions
    /*" Returns an array of #{GIMessageFilterAction} objects if available. nil otherwise. "*/
{
    if (_actionsCache == (id)self) {
        NSArray* actionDefinitions;

        if (actionDefinitions = [_filterDefinition objectForKey: @"actions"]) {
			
            NSDictionary* actionDefinition;
            _actionsCache = [[NSMutableArray alloc] initWithCapacity: [actionDefinitions count]];

            NSEnumerator* enumerator = [actionDefinitions objectEnumerator];
            while (actionDefinition = [enumerator nextObject]) {
                GIMessageFilterAction *action;

                action = [[GIMessageFilterAction alloc] initWithActionDefinitionDictionary: actionDefinition];
                [(NSMutableArray*)_actionsCache addObject: action];
                [action release];
            }
        } else {
            _actionsCache = nil;
        }
    }
    return _actionsCache;
}

- (void) setActions:(NSArray*) someActions
    /*" Sets the actions that are assiciated with the receiver. "*/
{
    // build actionDefinitions array
    NSMutableArray *actionDefinitions;
    NSEnumerator *enumerator;
    GIMessageFilterAction *action;

    NSParameterAssert(someActions != nil);

    actionDefinitions = [NSMutableArray arrayWithCapacity:[someActions count]];
    enumerator = [someActions objectEnumerator];
    while (action = [enumerator nextObject])
    {
        [actionDefinitions addObject:[action actionDefinitionDictionary]];
    }

    [[self _filterDefinition] setObject: actionDefinitions forKey: @"actions"];

    // take care of cache
    if (_actionsCache != (id)self)
    {
        [_actionsCache autorelease];
    }
    _actionsCache = [someActions retain];

    // model changed
    [[NSNotificationCenter defaultCenter] postNotificationName:GIMessageFiltersDidChangeNotification object:self];
}

- (NSArray*) expressions
/*" Returns an array of #{GIMessageFilterExpression} objects if available. nil otherwise. "*/
{
    if (_expressionsCache == (id)self)
    {
        NSArray* expressionDefinitions;

        if ((expressionDefinitions = [_filterDefinition objectForKey: @"expressions"]) || ([self _expression])) {
            _expressionsCache = [[NSMutableArray alloc] initWithCapacity:[expressionDefinitions count] ? [expressionDefinitions count] : 1];

            NSEnumerator* enumerator = [expressionDefinitions objectEnumerator];
			NSDictionary *expressionDefinition;
            while (expressionDefinition = [enumerator nextObject]) {
                GIMessageFilterExpression *expression;

                expression = [[GIMessageFilterExpression alloc] initWithExpressionDefinitionDictionary: expressionDefinition];
                [(NSMutableArray *)_expressionsCache addObject: expression];
                [expression release];
            }
            
            // upwards compability
            if ([self _expression]) {
                [(NSMutableArray *)_expressionsCache addObject:[self _expression]];
                [self _setExpression: nil];

                // model changed
                [[NSNotificationCenter defaultCenter] postNotificationName:GIMessageFiltersDidChangeNotification object:self];
            }

        }
        else
        {
            GIMessageFilterExpression *expression;

            _expressionsCache = [[NSMutableArray alloc] initWithCapacity:1];

            expression = [[GIMessageFilterExpression alloc] initWithExpressionDefinitionDictionary:[NSDictionary dictionary]];
            [(NSMutableArray *)_expressionsCache addObject:expression];
            
            [expression release];
        }
    }
    return _expressionsCache;
}

- (void) setExpressions:(NSArray*) someExpressions
/*" Sets the expressions that are assiciated with the receiver. "*/
{
    // build expressionDefinitions array
    NSMutableArray *expressionsDefinitions;
    NSEnumerator *enumerator;
    GIMessageFilterExpression *expression;

    NSParameterAssert(someExpressions != nil);

    expressionsDefinitions = [NSMutableArray arrayWithCapacity:[someExpressions count]];
    enumerator = [someExpressions objectEnumerator];
    while (expression = [enumerator nextObject])
    {
        [expressionsDefinitions addObject:[expression expressionDefinitionDictionary]];
    }

    [[self _filterDefinition] setObject: expressionsDefinitions forKey: @"expressions"];

    // take care of cache
    if (_expressionsCache != (id)self) {
        [_expressionsCache autorelease];
    }
    _expressionsCache = [someExpressions retain];

    // model changed
    [[NSNotificationCenter defaultCenter] postNotificationName: GIMessageFiltersDidChangeNotification object:self];
}

- (BOOL) isActive
/*" Returns whether the receiver will be used in filtering operations or not. "*/
{
    if (_isActiveCache == -1) {
        _isActiveCache = [[_filterDefinition objectForKey: @"isActive"] intValue];
    }

    return _isActiveCache != 0;
}

- (void) setIsActive: (BOOL) aBool
/*" Sets whether the receiver will be used in filtering operations or not. "*/
{
    if (aBool) {
        _isActiveCache = 1;
    } else {
        _isActiveCache = 0;
    }
    [[self _filterDefinition] setObject: [NSNumber numberWithInt:_isActiveCache] forKey: @"isActive"];

    // model changed
    [[NSNotificationCenter defaultCenter] postNotificationName:GIMessageFiltersDidChangeNotification object:self];
}

- (BOOL) allExpressionsMustMatch
/*" Returns whether the receiver matches only if all expressions match. "*/
{
    if (_allExpressionsMustMatchCache == -1) {
        _allExpressionsMustMatchCache = [[_filterDefinition objectForKey: @"allExpressionsMustMatch"] intValue];
    }
    return _allExpressionsMustMatchCache != 0;
}

- (void) setAllExpressionsMustMatch: (BOOL) aBool
/*" Sets whether the receiver matches only if all expressions match. "*/
{
    if (aBool) {
        _allExpressionsMustMatchCache = 1;
    } else {
        _allExpressionsMustMatchCache = 0;
    }
    [[self _filterDefinition] setObject: [NSNumber numberWithInt:_allExpressionsMustMatchCache] forKey: @"allExpressionsMustMatch"];

    // model changed
    [[NSNotificationCenter defaultCenter] postNotificationName:GIMessageFiltersDidChangeNotification object:self];
}

// filtering
- (BOOL) matchesForMessage: (GIMessage*) message flags:(int)flags
/*" Returns YES if the receiver matches for the given message and scope. NO otherwise. "*/
{
    if ([self isActive]) 
    {
        NSEnumerator *enumerator;
        GIMessageFilterExpression *expression;
        BOOL result = NO;
        
        enumerator = [[self expressions] objectEnumerator];
        
        BOOL allExpressionsMustMatch = [self allExpressionsMustMatch];
        while (expression = [enumerator nextObject]) 
        {
            if ([expression matchesForMessage:message flags:flags]) 
            {
                //OPDebugLog2(FILTERDEBUG, OPINFO, @"Filter %@ matches for message %@.", self, [message messageId]);
                
                if (! allExpressionsMustMatch) return YES;
                
                result = YES;
            } 
            else 
            {
                if (allExpressionsMustMatch) return NO;
            }
        }
        return result;
    }
    
    return NO;
}

// Class methods formally in filterCenter...



+ (void) moveFilter:(id)filter toIndex:(int)newIndex
/*"Changes order of the filters."*/
{
    int diff;
    int oldIndex = [[self filters] indexOfObject:filter];
    
    if (oldIndex == NSNotFound) return;
    
    if (newIndex == oldIndex) return;
    
    if (oldIndex < newIndex)
    {
        diff = -1;
    } else {
        diff = 0;
    }
    
    [filter retain];
    [self removeFilterAtPosition:oldIndex];
    [self insertFilter:filter atPosition:newIndex + diff];
    [filter release];
    
    // model changed
    [[NSNotificationCenter defaultCenter] postNotificationName:GIMessageFiltersDidChangeNotification object:self];
}

+ (void) insertFilter:(id)filter atPosition:(int)anIndex
/*" Inserts a new filter at index anIndex. If the filter is already present nothing is done. "*/
{
	NSMutableArray *_filters;
	
	_filters = (NSMutableArray *)[self filters];
	
    if (! [_filters containsObject:filter]) 
	{
        [_filters insertObject:filter atIndex:anIndex];
		
        // model changed
        [[NSNotificationCenter defaultCenter] postNotificationName:GIMessageFiltersDidChangeNotification object:self];
    }
}

+ (void) removeFilterAtPosition:(int)anIndex
/*" Removes filter from position anIndex. "*/
{
	NSMutableArray *_filters = (NSMutableArray *)[self filters];

    NSParameterAssert( (anIndex >= 0) && (anIndex < [_filters count]) );
    [_filters removeObjectAtIndex:anIndex];
	
    // model changed
    [[NSNotificationCenter defaultCenter] postNotificationName:GIMessageFiltersDidChangeNotification object:self];
}

// notifications

+ (void) filtersDidChange: (NSNotification*) aNotification
    /*" Saves the filter definitions delayed to disk. "*/
{
    NSNotification *notification;
	
    notification = [NSNotification notificationWithName:GIMessageFilterCenterDelayedWriteFilters object:self];
    [[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostWhenIdle coalesceMask:NSNotificationCoalescingOnName | NSNotificationCoalescingOnSender forModes: nil];
}

+ (void) delayedWriteFilters: (NSNotification*) aNotification
    /*" Saves the filter definitions to disk. "*/
{
    [self writeFilters];
}

// filtering

+ (NSArray*) filtersMatchingForMessage: (GIMessage*) message flags:(int)flags
	/*" Returns a (sub)set of the receiver's filters which match for the given
    message for the given scope (see %{GIMessageFilter} for details). "*/
{
    NSMutableArray *result = [NSMutableArray array];
    NSEnumerator *enumerator = [[self filters] objectEnumerator];
    GIMessageFilter *filter;
    
    while (filter = [enumerator nextObject]) 
    {
        if ([filter matchesForMessage:message flags:flags]) 
        {
            [result addObject:filter];
        }
    }
    
    return result;
}

+ (NSSet*) relevantSpamFilterHeaders 
/*" Returns a set of header names as NSStrings that are used in spam filter processing. "*/
{
	static NSSet* spamFilterHeaders = nil;
	if (!spamFilterHeaders) {
		spamFilterHeaders = [[NSSet alloc] initWithObjects: @"Subject", @"Content-Type", @"From", nil];
	}
	return spamFilterHeaders;
}


+ (BOOL) filterMessage: (GIMessage*) message flags: (int) flags
/*" Filters the given message. Returns YES if message was inserted/moved into a box
    different to currentBox. NO otherwise. TODO: Document flags! "*/
{
    BOOL inserted = NO;
    BOOL shouldStopFiltering = NO;
    
	if (YES /* use junk filter preference here */) {
	
		// DO not check own messages for spam.
		// Do not check messages by people in our address book.

		OPInternetMessage* im = [message internetMessage];
		// Extract all words in the header and body into the words array:		
		NSMutableArray* words = [NSMutableArray array];
		// Headers:
		NSEnumerator* headerEnumerator = [[im headerFields] objectEnumerator];
		OPObjectPair* header;
		while (header = [headerEnumerator nextObject]) {
			//NSString* headerWords = [im bodyForHeaderField: headerName];
			
			
			NSString* headerName = [header firstObject];
			
			// For now, only scan subject:
			if ([headerName isEqualToString: @"Subject"] || [headerName isEqualToString: @"Content-Type"]) {
				OPDebugLog(GIMESSAGEFILTER, OPINFO, @"Header: %@", header);
				
				// All header words get the "h:" prefix:
				[GIJunkFilter addWordsFromString: [header secondObject] 
									  withPrefix: @"h" 
										 toArray: words];
			}
		}
		
		// Body:
		[GIJunkFilter addWordsFromString: [im contentAsPlainString]
							  withPrefix: nil
								 toArray: words];

		OPDebugLog(GIMESSAGEFILTER, OPINFO, @"Words used as spamfilter input: %@", words);
		NSEnumerator* wordEnumerator = [words objectEnumerator];
		
		BOOL isSpam = [[GIJunkFilter sharedInstance] isSpamMessage: wordEnumerator];
		if (isSpam) {
			OPDebugLog(GIMESSAGEFILTER, OPINFO, @"Message %@ considered SPAM!", message);
			[message addFlags: OPJunkMailStatus];
			NSAssert([message flags] & OPJunkMailStatus, @"Setting Junk Flag did not work.");
		}
	}
	
    NSEnumerator* filterEnumerator = [[self filtersMatchingForMessage: message 
																flags: flags] objectEnumerator];
	GIMessageFilter* filter;
    while ( (filter = [filterEnumerator nextObject]) && (! shouldStopFiltering) ) {
        NSEnumerator* actionEnumerator = [[filter actions] objectEnumerator];
		GIMessageFilterAction* action;
        while (action = [actionEnumerator nextObject]) {
            if ([action state] == NSOnState) {
                // Do it only when active:
                BOOL filterPutInBox = NO;
                
                shouldStopFiltering |= [GIMessageFilterAction performAction: action 
																withMessage: message 
																	  flags: flags 
														  putIntoMessagebox: &filterPutInBox];
                
                inserted |= filterPutInBox;
            }
        }
    }
    return inserted;
}

static NSString *_filterDefinitionsPath()
/*" Ensures that Ginko's Application Support folder is in place and returns the path for the filter
definition plist. "*/
{
    static NSString *path = nil;
    
    if (! path) 
    {
        path = [[[NSApp applicationSupportPath] stringByAppendingPathComponent: @"FilterDefinitions.plist"] retain]; // once and for all
    }
    
    return path;
}


+ (NSMutableArray *)filtersFromPlist:(NSArray*) plist
	/*" Instantiates filters from definition dictionaries. "*/
{
    NSEnumerator *enumerator;
    NSDictionary *definitionDictionary;
    NSMutableArray *result;
    
    if (! plist) 
    {
        return [NSMutableArray array];
    }
    
    result = [NSMutableArray arrayWithCapacity:[plist count]];
    
    enumerator = [plist objectEnumerator];
    while (definitionDictionary = [enumerator nextObject]) 
    {
        GIMessageFilter *filter;
        
        filter = [[GIMessageFilter allocWithZone:[result zone]] initWithFilterDefinitionDictionary:definitionDictionary];
        [result addObject:filter];
        [filter release];
    }
    return result;
}

+ (NSArray*) plistFromFilters:(NSArray*) filters
	/*" Gathers a list of definition dictionaries from the given filters. "*/
{
    NSMutableArray *result;
    NSEnumerator *enumerator;
    GIMessageFilter *filter;
	
    result = [NSMutableArray arrayWithCapacity:[filters count]];
	
    enumerator = [filters objectEnumerator];
    while (filter = [enumerator nextObject]) 
	{
        [result addObject:[filter filterDefinitionDictionary]];
    }
	
    return result;
}

+ (BOOL) writeFilters
	/*"Writes filter definitions to disk."*/
{
    return [[self plistFromFilters:[self filters]] writeToFile:_filterDefinitionsPath() atomically: YES];
}

+ (NSArray*) filters
	/*"Simple accessor. An ordered array of filters"*/
{
	static NSMutableArray *_filters = nil;
	if (!_filters) 
	{
		id plist = [NSArray arrayWithContentsOfFile:_filterDefinitionsPath()];
		
		_filters = [[self filtersFromPlist:plist] retain];
		
		// observe changes
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(filtersDidChange:) name: GIMessageFiltersDidChangeNotification object: nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(delayedWriteFilters:) name: GIMessageFilterCenterDelayedWriteFilters object:self];
	}
	
    return _filters;
}

@end
