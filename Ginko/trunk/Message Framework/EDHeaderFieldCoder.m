//---------------------------------------------------------------------------------------
//  EDHeaderFieldCoder.m created by erik on Sun 24-Oct-1999
//  @(#)$Id: EDHeaderFieldCoder.m,v 1.3 2004/12/25 15:23:59 mikesch Exp $
//
//  Copyright (c) 1999 by Erik Doernenburg. All rights reserved.
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
#import "EDHeaderFieldCoder.h"


//---------------------------------------------------------------------------------------
    @implementation EDHeaderFieldCoder
//---------------------------------------------------------------------------------------

//---------------------------------------------------------------------------------------
//	FACTORY
//---------------------------------------------------------------------------------------

+ (id) decoderWithFieldBody: (NSString*) fieldBody
{
    return [[[self alloc] initWithFieldBody:fieldBody] autorelease];
}


//---------------------------------------------------------------------------------------
//	INIT & DEALLOC
//---------------------------------------------------------------------------------------

- (id) initWithFieldBody: (NSString*) body
{
    assert(NO);
    return self;
}


- (void)dealloc
{
    [super dealloc];
}


//---------------------------------------------------------------------------------------
//	CODING
//---------------------------------------------------------------------------------------

- (NSString*) stringValue
{
    assert(NO);
    return nil; // keep compiler happy...
}


- (NSString*) fieldBody
{
    assert(NO);
    return nil; // keep compiler happy...
}

// dth
+ (NSString*) stringFromFieldBody: (NSString*) body
                     withFallback: (BOOL) fallback {
    /*"If fallback is set, returns body whenever decoding fails
    instead of thowin an exception."*/
    // dth: lame default implementation:
    NSString* result;
    if (!body)
        return nil;
    if (!fallback)
        return [[self decoderWithFieldBody: body] stringValue];
    // else fall back to the body:
    NS_DURING
	result = [[self decoderWithFieldBody: body] stringValue];
    NS_HANDLER
        result = body;
    NS_ENDHANDLER
    return result;
}

//---------------------------------------------------------------------------------------
    @end
//---------------------------------------------------------------------------------------
