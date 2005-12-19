//---------------------------------------------------------------------------------------
//  ED-ObjectPair.m created by erik on Sat 29-Aug-1998
//  @(#)$Id: OPObjectPair.m,v 1.1 2004/12/22 17:11:05 theisen Exp $
//
//  Copyright (c) 1998-1999 by Erik Doernenburg. All rights reserved.
//  Changes by Dirk Theisen, Objectpark Group.
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
#import "OPObjectPair.h"


//---------------------------------------------------------------------------------------
    @implementation OPObjectPair
//---------------------------------------------------------------------------------------

/*" From a purely functional point OPObjectPair does not add anything to NSArray. However, OPObjectPair can be used when a design explicitly deals with a relationship between two objects, typically an association of a value or an object with another object. An array of OPObjectPairs can be used instead of an NSDictionary when the order of key/value pairs is relevant and lookups of values by key do not need to be fast. OPObjectPairs also use less memory than NSArray and have a better hash function. (If you know LISP you probably use pairs for all sorts of other structures.) "*/


//---------------------------------------------------------------------------------------
//	CLASS INITIALISATION
//---------------------------------------------------------------------------------------

+ (void) initialize
{
    [self setVersion:1];
}


//---------------------------------------------------------------------------------------
//	FACTORY
//---------------------------------------------------------------------------------------

/*" Creates and returns a pair containing !{nil} for both first and second object. "*/

+ (id)pair
{
    return [[[self alloc] init] autorelease];
}


/*" Creates and returns a pair containing the objects in aPair. "*/

+ (id)pairWithObjectPair: (OPObjectPair*) aPair
{
    return [[[self alloc] initWithObjects:[aPair firstObject]:[aPair secondObject]] autorelease];
}


/*" Creates and returns a pair containing anObject and anotherObject. "*/

+ (id)pairWithObjects:(id)anObject:(id)anotherObject
{
    return [[[self alloc] initWithObjects:anObject:anotherObject] autorelease];
}


//---------------------------------------------------------------------------------------
//	INIT
//---------------------------------------------------------------------------------------

/*" Initialises a newly allocated pair by adding the objects from %aPair to it. Objects are, of course, retained. "*/

- (id)initWithObjectPair: (OPObjectPair*) aPair
{
    return [self initWithObjects:[aPair firstObject]:[aPair secondObject]];
}


/*" Initialises a newly allocated pair by adding anObject and anotherObject to it. Objects are, of course, retained. "*/

- (id)initWithObjects:(id)anObject:(id)anotherObject
{
    [super init];
    firstObject = [anObject retain];
    secondObject = [anotherObject retain];
    return self;
}


- (void) dealloc
{
    [firstObject release];
    [secondObject release];
    [super dealloc];
}


//---------------------------------------------------------------------------------------
//	NSCODING
//---------------------------------------------------------------------------------------

- (void) encodeWithCoder: (NSCoder*) encoder
{
    [encoder encodeObject:firstObject];
    [encoder encodeObject:secondObject];
}


- (id)initWithCoder: (NSCoder*) decoder
{
    unsigned int version;

    [super init];
    version = [decoder versionForClassName: @"OPObjectPair"];
    if(version > 0)
        {
        firstObject = [[decoder decodeObject] retain];
        secondObject = [[decoder decodeObject] retain];
        }
    return self;
}


//---------------------------------------------------------------------------------------
//	NSCOPYING
//---------------------------------------------------------------------------------------

- (id)copyWithZone: (NSZone*) zone
{
    if(NSShouldRetainWithZone(self, zone))
        return [self retain];
    return [[OPObjectPair allocWithZone:zone] initWithObjects:firstObject:secondObject];
}


- (id)mutableCopyWithZone: (NSZone*) zone
{
    return [[EDMutableObjectPair allocWithZone:zone] initWithObjects:firstObject:secondObject];
}


//---------------------------------------------------------------------------------------
//	DESCRIPTION & COMPARISONS
//---------------------------------------------------------------------------------------

- (NSString*) description
{
    return [NSString stringWithFormat: @"<%@ 0x%x: (%@, %@)>", NSStringFromClass(isa), (void *)self, firstObject, secondObject];
}


- (unsigned) hash
{
    return [firstObject hash] ^ [secondObject hash];
}


- (BOOL) isEqual: (id) otherObject
{
    id otherFirstObject, otherSecondObject;

    if(otherObject == nil)
        return NO;
    else if((isa != ((OPObjectPair *)otherObject)->isa) && ([otherObject isKindOfClass:[OPObjectPair class]] == NO))
        return NO;

    otherFirstObject = ((OPObjectPair *)otherObject)->firstObject;
    otherSecondObject = ((OPObjectPair *)otherObject)->secondObject;

    return ( (((firstObject == nil) && (otherFirstObject == nil)) || [firstObject isEqual:otherFirstObject]) &&
             (((secondObject == nil) && (otherSecondObject == nil)) || [secondObject isEqual:otherSecondObject]) );
}


//---------------------------------------------------------------------------------------
//	ATTRIBUTES
//---------------------------------------------------------------------------------------

/*" Returns the first object. Note that this can be !{nil}. "*/

- (id) firstObject
{
    return firstObject;
}

- (id) objectAtIndex: (unsigned) index
/*" Index must be 0 (firstObject) or 1 (secondObject). "*/
{
	NSParameterAssert(index<2);
	return index == 0 ? firstObject : secondObject;
}


/*" Returns the second object. Note that this can be !{nil}. "*/

- (id)secondObject
{
    return secondObject;
}


//---------------------------------------------------------------------------------------
//	CONVENIENCE
//---------------------------------------------------------------------------------------

/*" Returns an array containing all objects in the pair. Because a pair can contain !{nil} references, this array can have zero, one or two objects. If both objects in the pair are not !{nil} the first object preceedes the second in the array."*/

- (NSArray*) allObjects
{
    if(firstObject == nil)
        return [NSArray arrayWithObjects:secondObject, nil];
    return [NSArray arrayWithObjects:firstObject, secondObject, nil];
}


//---------------------------------------------------------------------------------------
    @end
//---------------------------------------------------------------------------------------

//---------------------------------------------------------------------------------------
@implementation EDMutableObjectPair
//---------------------------------------------------------------------------------------

/*" Mutable variant of object pair allows objects to be changed. "*/


//---------------------------------------------------------------------------------------
//	NSCOPYING
//---------------------------------------------------------------------------------------

- (id)copyWithZone: (NSZone*) zone
{
    return [[OPObjectPair allocWithZone:zone] initWithObjects:firstObject:secondObject];
}


- (id)mutableCopyWithZone: (NSZone*) zone
{
    return [[EDMutableObjectPair allocWithZone:zone] initWithObjects:firstObject:secondObject];
}


//---------------------------------------------------------------------------------------
//	ACCESSOR METHODS
//---------------------------------------------------------------------------------------

/*" Sets the firstObject of the receiver to %anObject. "*/

- (void) setFirstObject:(id)anObject
{
    [anObject retain];
    [firstObject release];
    firstObject = anObject;
}


/*" Sets the secondObject of the receiver to %anObject. "*/

- (void) setSecondObject:(id)anObject
{
    [anObject retain];
    [secondObject release];
    secondObject = anObject;
}


//---------------------------------------------------------------------------------------
@end
//---------------------------------------------------------------------------------------

