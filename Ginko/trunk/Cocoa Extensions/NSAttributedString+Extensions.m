//---------------------------------------------------------------------------------------
//  NSAttributedString+Extensions.h created by erik on Tue 05-Oct-1999
//  $Id: NSAttributedString+Extensions.m,v 1.2 2005/01/26 09:44:51 mikesch Exp $
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
#import "NSAttributedString+Extensions.h"

@implementation NSAttributedString (OPExtensions)

- (NSAttributedString *)attributedStringByRemovingSourroundingWhitespacesAndNewLines
{
    NSRange start, end, result;
    NSString *s;
    
    static NSCharacterSet *iwsSet = nil;
    
    s = [self string];
    
    if(iwsSet == nil)
        iwsSet = [[[NSCharacterSet whitespaceAndNewlineCharacterSet] invertedSet] retain];
    
    start = [s rangeOfCharacterFromSet:iwsSet];
    if(start.length == 0)
        return [[[NSAttributedString alloc] init] autorelease]; // string is empty or consists of whitespace only
    
    end = [s rangeOfCharacterFromSet:iwsSet options:NSBackwardsSearch];
    if((start.location == 0) && (end.location == [self length] - 1))
        return self;
    
    result = NSMakeRange(start.location, end.location + end.length - start.location);
    
    return [self attributedSubstringFromRange:result];	
}

@end

//---------------------------------------------------------------------------------------
    @implementation NSMutableAttributedString(EDExtensions)
//---------------------------------------------------------------------------------------

/*" Various common extensions to #NSMutableAttributedString. "*/

/*" Appends  %string to the receiver using the text attributes as set at the end of the receiver. "*/

- (void) appendString: (NSString*) string
{
#if 0
    [self appendAttributedString:[[[NSAttributedString alloc] initWithString:string] autorelease]];
#else
    [self replaceCharactersInRange:NSMakeRange([self length], 0) withString:string];
#endif
}

/*" Appends  %string to the receiver using the %attributes passed in. "*/

- (void) appendString: (NSString*) string withAttributes: (NSDictionary*) attributes
{
    unsigned int location;

    location = [self length];
    [self appendString:string];
    [self setAttributes:attributes range:NSMakeRange(location, [self length] - location)];
}


//---------------------------------------------------------------------------------------
    @end
//---------------------------------------------------------------------------------------
