//---------------------------------------------------------------------------------------
//  NSArray+Extensions.m created by erik on Thu 28-Mar-1996
//  @(#)$Id: NSArray+Extensions.m,v 1.1 2004/12/23 16:45:15 theisen Exp $
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

#import <Foundation/Foundation.h>
#import "NSArray+Extensions.h"
//#import "NSObject+Extensions.h"
#import "EDObjcRuntime.h"


static NSComparisonResult compareAttributes(id object1, id object2, void *context)
{
    // The cast of the first value to an NSString is merely to avoid a compiler warning that compare:
    // is declared in several classes. It does not limit the attribute values to strings.
    return [(NSString*) [object1 valueForKey:(id)context] compare:[object2 valueForKey:(id)context]];
}


//=======================================================================================
    @implementation NSArray (OPExtensions)
//=======================================================================================

/*" Various common extensions to #NSArray. "*/

//---------------------------------------------------------------------------------------

/*" If the array contains exactly one object this is returned.
    Otherwise an #NSInternalInconsistencyException is raised. "*/

- (id)singleObject
{
    if([self count] != 1)
        [NSException raise:NSInternalInconsistencyException format: @"-[%@ %@]: Attempt to retrieve single object from an array that contains %d objects.",
                                                                    NSStringFromClass(isa), NSStringFromSelector(_cmd), [self count]];
    return [self objectAtIndex:0];
}

//---------------------------------------------------------------------------------------

/*" Return the object at index 0 or !{nil} if the array is empty.
    #Note: The method #firstObject is also implemented in the HTML framework
    which is sometimes loaded in AppKit applications.
    Unfortunately, its implemenation differs in that it raises an exception if
    the array is empty. (Don't ask why they did that!)
    So, you either live with this or call #applyFirstObjectPatch before the HTML
    framework is loaded. "*/

- (id)firstObject
{
    if([self count] == 0)
        return nil;
    return [self objectAtIndex:0];
}


#ifndef EDCOMMON_OSXBUILD
#ifdef __MACH__

static EDObjcMethodInfo myFirstObjectMethod;

/*" See description of #{firstObject}. "*/

+ (void) applyFirstObjectPatch
{
    myFirstObjectMethod = EDObjcClassGetInstanceMethod([NSArray class], @selector(firstObject));
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_bundleWasLoaded:) name: NSBundleDidLoadNotification object: nil];
}

+ (void) _bundleWasLoaded: (NSNotification*) n
{
    EDObjcMethodInfo evilFirstObjectMethod;

    if([[[n object] bundlePath] hasSuffix: @"Library/PrivateFrameworks/HTML.framework"] == NO)
        return;

    evilFirstObjectMethod = EDObjcClassGetInstanceMethod([NSArray class], @selector(firstObject));
    evilFirstObjectMethod->method_imp = myFirstObjectMethod->method_imp;
    NSLog(@"Applied 'firstObject' patch to HTML framework");
}

#endif
#endif

//---------------------------------------------------------------------------------------

/*" Returns a new array that is a copy of the receiver with the objects arranged
    in reverse. "*/

- (NSArray*) reversedArray
{
    return [[self reverseObjectEnumerator] allObjects];
}


/*" Returns a new array that is a copy of the receiver with the objects 
    rearranged randomly. "*/

- (NSArray*) shuffledArray
{
    NSMutableArray *copy = [[self mutableCopyWithZone:[self zone]] autorelease];
    [copy shuffle];
    return copy;
}


/*" Returns a new array that is a copy of the receiver with the objects sorted
    objects according to their compare: method "*/

- (NSArray*) sortedArray
{
    return [self sortedArrayUsingSelector:@selector(compare:)];
}


/*" Returns a new array that is a copy of the receiver with the objects sorted
    according to the values of their attribute %{attributeName}.
    These are retrieved using key/value coding. "*/

- (NSArray*) sortedArrayByComparingAttribute: (NSString*) attributeName
{
    return [self sortedArrayUsingFunction:compareAttributes context:attributeName];
}


/*" If the receiver contains instances of #NSArray the objects from the embedded
    array are transferred to the receiver and the embedded array is deleted.
    This method works recursively which means that embedded arrays are also
    flattened before their contents are transferred. "*/

- (NSArray*) flattenedArray
{
    NSMutableArray	*flattenedArray;
    id				object;
    unsigned int	i, n = [self count];

    flattenedArray = [[[NSMutableArray allocWithZone:[self zone]] init] autorelease];
    for(i = 0; i < n; i++)
        {
        object = [self objectAtIndex:i];
        if([object isKindOfClass:[NSArray class]])
            [flattenedArray addObjectsFromArray:[object flattenedArray]];
        else
            [flattenedArray addObject:object];
        }

    return flattenedArray;
}


//---------------------------------------------------------------------------------------

/*" Uses each object in the receiver as a key and looks up the corresponding 
    value in %mapping.
    All these values are added in the same order to the array returned.
    Note that this method raises an Exception if any of the objects in the 
    receiver are not found as a key in %mapping."*/

- (NSArray*) arrayByMappingWithDictionary: (NSDictionary*) mapping
{
    NSMutableArray	*mappedArray;
    unsigned int	i, n = [self count];

    mappedArray = [[[NSMutableArray allocWithZone:[self zone]] initWithCapacity:n] autorelease];
    for(i = 0; i < n; i++)
        [mappedArray addObject:[mapping objectForKey:[self objectAtIndex:i]]];

    return mappedArray;
}


/*" Invokes the method described by %selector in each object in the receiver.
    All returned values are added in the same order to the array returned. "*/

- (NSArray*) arrayByMappingWithSelector:(SEL)selector
{
    NSMutableArray	*mappedArray;
    unsigned int	i, n = [self count];

    mappedArray = [[[NSMutableArray allocWithZone:[self zone]] initWithCapacity:n] autorelease];
    for(i = 0; i < n; i++)
        [mappedArray addObject:EDObjcMsgSend([self objectAtIndex:i], selector)];

    return mappedArray;
}


/*" Invokes the method described by %selector in each object in the receiver,
    passing %object as an argument.
    All returned values are added in the same order to the array returned. "*/

- (NSArray*) arrayByMappingWithSelector:(SEL)selector withObject:(id)object
{
    NSMutableArray	*mappedArray;
    unsigned int	i, n = [self count];

    mappedArray = [[[NSMutableArray allocWithZone:[self zone]] initWithCapacity:n] autorelease];
    for(i = 0; i < n; i++)
        [mappedArray addObject:EDObjcMsgSend1([self objectAtIndex:i], selector, object)];

    return mappedArray;
}


//---------------------------------------------------------------------------------------

/*" Returns an array with all duplicates removed (i.e. uniqued).
    The order of the entries is preserved. "*/

- (NSArray*) arrayByRemovingDuplicates
{
    NSMutableArray* result = [NSMutableArray arrayWithArray:self];
    
    [result removeDuplicates];
    
    return result;
}


//---------------------------------------------------------------------------------------

/*" Returns an array containing all objects from the receiver up to
    (not including) the object at %index. "*/

- (NSArray*) subarrayToIndex:(unsigned int)index
{
    return [self subarrayWithRange:NSMakeRange(0, index)];
}


/*" Returns an array containing all objects from the receiver starting with the
    object at %index. "*/

- (NSArray*) subarrayFromIndex:(unsigned int)index
{
    return [self subarrayWithRange:NSMakeRange(index, [self count] - index)];
}

//---------------------------------------------------------------------------------------

/*" Returns YES if the receiver is contained in %otherArray at %offset. "*/

- (BOOL)isSubarrayOfArray:(NSArray*) other atOffset:(int)offset
{
    int	i, n = [self count];

    if(n > offset + [other count])
        return NO;
    for(i = 0; i < n; i++)
        if([[self objectAtIndex:i] isEqual:[other objectAtIndex:offset + i]] == NO)
            return NO;
    return YES;
}

//---------------------------------------------------------------------------------------

/*" Returns the first index at which %otherArray is contained in the receiver;
    or !{NSNotFound} otherwise. "*/

- (unsigned int)indexOfSubarray:(NSArray*) other
{
    int		i, n = [self count], length, location = 0;

    do
        {
        if((length = n - location - [other count] + 1) <= 0)
            return NSNotFound;
        if((i = [self indexOfObject:[other objectAtIndex:0] inRange:NSMakeRange(location, length)]) == NSNotFound)
            return NSNotFound;
        location = i + 1;
        }
    while([other isSubarrayOfArray:self atOffset:i] == NO);

    return i;
}

//---------------------------------------------------------------------------------------

/*" Creates and returns an array of NSString objects.
    These refer to all files of the type specified in %type that can be found in
    the directory %aPath. "*/

+ (NSArray*) arrayWithFilesOfType: (NSString*) type inPath: (NSString*) aPath
{
    NSString		*firstName;
    NSArray    	   	*allNames = nil;
    unsigned int	count;

    if(![aPath hasSuffix: @"/"])
        aPath = [aPath stringByAppendingString: @"/"];

    count = [aPath completePathIntoString:&firstName caseSensitive: YES matchesIntoArray:&allNames filterTypes:[NSArray arrayWithObject:type]];
    return allNames;
}


/*" Creates and returns an array of NSString objects.
    These refer to all files of a type specified in %type that can be found in a
    directory named %libraryName in any of the standard library locations as 
    returned by #NSSearchPathForDirectoriesInDomains. "*/

+ (NSArray*) arrayWithFilesOfType: (NSString*) type inLibrary: (NSString*) libraryName
{
    NSMutableArray	*result;
    NSArray* libPathList;
    NSEnumerator	*pathEnum;
    NSString		*path;

    result = [NSMutableArray array];
    libPathList = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSAllDomainsMask, YES);
    pathEnum = [libPathList objectEnumerator];
    while((path = [pathEnum nextObject]) != nil)
        {
        path = [path stringByAppendingPathComponent:libraryName];
        [result addObjectsFromArray:[NSArray arrayWithFilesOfType:type inPath:path]];
       }
    return result;
}


/*" Returns an array containing all library paths. "*/

+ (NSArray*) librarySearchPaths
{
    static NSMutableArray *paths = nil;

    if(paths == nil)
        {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        paths = [NSSearchPathForDirectoriesInDomains(NSAllLibrariesDirectory, NSAllDomainsMask, YES) retain];
        [pool release];
        }
    return paths;
}

//=======================================================================================
    @end
//=======================================================================================


//=======================================================================================
    @implementation NSMutableArray(EDExtensions)
//=======================================================================================

/*" Various common extensions to #NSMutableArray. "*/

/*" Removes duplicate entries from the receiver (.i.e. uniqueing the entries).
    The order of the entries is preserved. "*/

- (void) removeDuplicates
{
    NSMutableSet *seen = [NSMutableSet set];
    unsigned int i = 0;
    while (i < [self count]) {
        id entry = [self objectAtIndex:i];
        
        if ([seen containsObject:entry])
            [self removeObjectAtIndex:i];
        else {
            [seen addObject:entry];
            i++;
        }
    }
}


/*" Randomly changes the order of the objects in the receiving array. "*/

- (void) shuffle
{
    int i, j, n;
    id	d;

    n = [self count];
    for(i = n - 1; i >= 0; i--)
        {
        j = random() % n;
        if(j == i)
            continue;
        d = [[self objectAtIndex:i] retain];
        [self replaceObjectAtIndex:i withObject:[self objectAtIndex:j]];
        [self replaceObjectAtIndex:j withObject:d];
        [d release];
        }
}


/*" Sorts objects according to their compare: method "*/

- (void) sort
{
    [self sortUsingSelector:@selector(compare:)];
}


/*" Sorts objects according to the values of their %{attributeName}.
    These are retrieved using key/value coding. "*/

- (void) sortByComparingAttribute: (NSString*) attributeName
{
    [self sortUsingFunction:compareAttributes context:attributeName];
}

- (void) pushObject: (id) obj
{
    [self addObject: obj];
}

- (id) popObject
{
    id result = [[[self lastObject] retain] autorelease];
    if (result) [self removeLastObject];
    return result;
}

//=======================================================================================
   @end
//=======================================================================================



