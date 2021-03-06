//---------------------------------------------------------------------------------------
//  NSString+MessageUtils.m created by erik on Sun 23-Mar-1997
//  @(#)$Id: NSString+MessageUtils.m,v 1.17 2005/04/05 01:02:31 theisen Exp $
//
//  Copyright (c) 1995-2000 by Erik Doernenburg. All rights reserved.
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

#import "NSCharacterSet+MIME.h"
#import "NSString+Extensions.h"
#import "NSString+MessageUtils.h"
#import "NSAttributedString+MessageUtils.h"
#import "NSAttributedString+Extensions.h"
#import "NSScanner+Extensions.h"
#import <Foundation/NSDebug.h>
#import "utilities.h"

#include <sys/types.h>
#include <sys/stat.h>


#if defined(__APPLE__) && !defined(UINT16_MAX)
#define UINT16_MAX USHRT_MAX
#endif

NSString* OPQuotationAttributeName       = @"OPQuotationAttributeName";
NSString* OPQuotationPrefixAttributeName = @"OPQuotationPrefixAttributeName";
NSString* OPAttachmentPathAttribute      = @"OPAttachmentPathAttribute";


//---------------------------------------------------------------------------------------
	@implementation NSString(OPMessageUtilities)
//---------------------------------------------------------------------------------------

//---------------------------------------------------------------------------------------
//	EXTRACTING SUBSRUCTURES
//---------------------------------------------------------------------------------------

- (BOOL) isValidMessageID
{ 	
	return [self hasPrefix: @"<"] && [self hasSuffix: @">"] && ([self rangeOfString: @"@"].length != 0);
}


- (NSString*) getURLFromArticleID
{
    NSScanner *scanner;
    NSString  *articleId;

    scanner = [NSScanner scannerWithString:self];
    if([scanner scanString: @"<" intoString: NULL])
        if([scanner scanUpToString: @">" intoString:&articleId])
            return [NSString stringWithFormat: @"news:%@", articleId];
    return nil;
}


/*

This next methods are a hack. We do need a new header coder that contains a proper
RFC822/RFC2047 parser for structured fields such as mail address lists, etc.

 */

- (NSString*) stringByRemovingBracketComments
{
    //NSCharacterSet	*stopSet;
    NSString		*chunk;
    NSScanner		*scanner;
    NSMutableString	*result;

    //stopSet = [NSCharacterSet characterSetWithCharactersInString: @"("];
    result = [[[NSMutableString allocWithZone:[self zone]] init] autorelease];
    scanner = [NSScanner scannerWithString:self];
    while([scanner isAtEnd] == NO)
        {
        //if([scanner scanUpToCharactersFromSet:stopSet intoString:&chunk] == YES)
		// This change needs testing:
		if([scanner scanUpToString: @"(" intoString:&chunk] == YES)
            [result appendString:chunk];
        if([scanner scanString: @"(" intoString: NULL] == YES)
            if([scanner scanUpToClosingBracketIntoString: NULL] == YES)
                [scanner scanString: @")" intoString: NULL];
        }

    return result;
}


- (NSString*) realnameFromEMailString
{
    static NSCharacterSet *skipChars = nil;	
    NSRange charPos, char2Pos, nameRange;
    
    if(skipChars == nil)
        skipChars = [[NSCharacterSet characterSetWithCharactersInString: @"\"' "] retain];
    
    if((charPos = [self rangeOfString: @"@"]).length == 0) {
        nameRange = NSMakeRange(0, [self length]);
    }
    else if((charPos = [self rangeOfString: @"<"]).length > 0) {
        nameRange = NSMakeRange(0, charPos.location);
    }
    else if((charPos = [self rangeOfString: @"("]).length > 0)
    {
        char2Pos = [self rangeOfString: @")"];          // empty brackets are ignored
        if((char2Pos.length > 0) && (char2Pos.location > charPos.location + 1))
            nameRange = NSMakeRange(charPos.location + 1, char2Pos.location - charPos.location - 1);
        else
            nameRange = NSMakeRange(0, [self length]);
    } else {
        nameRange = NSMakeRange(0, [self length]);
    }
    
    while((nameRange.length > 0) && [skipChars characterIsMember: [self characterAtIndex:nameRange.location]]) {
        nameRange.location += 1; nameRange.length -= 1;
    }
    while((nameRange.length > 0) && [skipChars characterIsMember: [self characterAtIndex:nameRange.location + nameRange.length - 1]]) {
        nameRange.length -= 1;
    }
    
    return [self substringWithRange: nameRange];
}


- (NSString*) addressFromEMailString
{
    static NSCharacterSet 	*nonAddressChars = nil;
    NSString 				*addr;
    NSRange 				d1Pos, d2Pos, atPos, searchRange, addrRange;

    if(nonAddressChars == nil) {
        NSMutableCharacterSet *workingSet;
        
        workingSet = [[[NSCharacterSet characterSetWithCharactersInString: @"()<>@,;:\\\"[]"] mutableCopy] autorelease];
        [workingSet formUnionWithCharacterSet:[NSCharacterSet controlCharacterSet]];
        [workingSet formUnionWithCharacterSet:[NSCharacterSet linebreakCharacterSet]];
        [workingSet formUnionWithCharacterSet:[NSCharacterSet whitespaceCharacterSet]];
//#ifdef EDMESSAGE_OSXBUILD        
//#warning ** workaround for broken implementation of -invertedSet in 5G64 
//        [workingSet formUnionWithCharacterSet:[NSCharacterSet characterSetWithRange:NSMakeRange(128, UINT16_MAX-128)]];
//#else
        [workingSet formUnionWithCharacterSet:[[NSCharacterSet standardASCIICharacterSet] invertedSet]];
//#endif        
        nonAddressChars = [workingSet copy];
    }
    
    if((d1Pos = [self rangeOfString: @"<"]).length > 0) {
        searchRange = NSMakeRange(NSMaxRange(d1Pos), [self length] - NSMaxRange(d1Pos));
        d2Pos = [self rangeOfString: @">" options:0 range:searchRange];
        if(d2Pos.length == 0)
            [NSException raise:NSGenericException format: @"Invalid e-mail address string: \"%@\"", self];
        addrRange = NSMakeRange(NSMaxRange(d1Pos), d2Pos.location - NSMaxRange(d1Pos));
        addr = [[self substringWithRange:addrRange] stringByRemovingSurroundingWhitespace];
    }
    else if((atPos = [self rangeOfString: @"@"]).length > 0) {
        searchRange = NSMakeRange(0, atPos.location);
        d1Pos = [self rangeOfCharacterFromSet:nonAddressChars options:NSBackwardsSearch range:searchRange];
        if(d1Pos.length == 0)
            d1Pos.location = 0;
        searchRange = NSMakeRange(NSMaxRange(atPos), [self length] - NSMaxRange(atPos));
        d2Pos = [self rangeOfCharacterFromSet:nonAddressChars options:0 range:searchRange];
        if(d2Pos.length == 0)
            d2Pos.location = [self length];
        addrRange = NSMakeRange(NSMaxRange(d1Pos), d2Pos.location - NSMaxRange(d1Pos));
        addr = [self substringWithRange:addrRange];
    }
    else {
        d2Pos = [self rangeOfCharacterFromSet:nonAddressChars];
        if(d2Pos.length == 0)
            d2Pos.location = [self length];
        addrRange = NSMakeRange(0, d2Pos.location);
        addr = [self substringWithRange:addrRange];
    }

    return addr;
}

/*
- (NSArray*) addressListFromEMailString
{
    NSCharacterSet	*stopSet;
    NSString		*chunk;
    NSScanner		*scanner;
    NSMutableString	*result;

    stopSet = [NSCharacterSet characterSetWithCharactersInString: @"\""];
    result = [[[NSMutableString allocWithZone:[self zone]] init] autorelease];
    scanner = [NSScanner scannerWithString:self];
    while([scanner isAtEnd] == NO)
        {
        if([scanner scanUpToCharactersFromSet:stopSet intoString:&chunk] == YES)
            [result appendString:chunk];
        if([scanner scanString: @"\"" intoString: NULL] == YES)
            if([scanner scanUpToCharactersFromSet:stopSet intoString:&chunk] == YES)
                [scanner scanString: @"\"" intoString: NULL];
        }
    return [[[result componentsSeparatedByString: @","] arrayByMappingWithSelector:@selector(stringByRemovingSurroundingWhitespace)] arrayByMappingWithSelector:@selector(addressFromEMailString)];
}
*/

- (NSString*) stringByRemovingReplyPrefix
/*" Removes prefixes like 'Re:', 'Re^3:', 'Re: Re: ' or 'Re[4]:' from the receiver. "*/
{
    static BOOL		didInitTable = NO;
    static short	delta[11][129];
    short	 		state;
    unsigned int	n, i, c, lastMatch;

    if(didInitTable == NO)
        {
        didInitTable = YES;
        memset(delta, 0, 10 * 129 * sizeof(short));
        for(i = 0; i < 129; i++)
            delta[6][i] = 1;
        delta[2]['r'] = 3; delta[2]['R'] = 3; delta[2][128] = 0;
        delta[3]['e'] = 4; delta[3]['E'] = 4; delta[3][128] = 0;
        delta[4]['^'] = 5; delta[4][':'] = 6; delta[4][128] = 0;
        delta[5]['0'] = 5; delta[5]['1'] = 5; delta[5]['2'] = 5;         delta[5]['3'] = 5;
        delta[5]['4'] = 5; delta[5]['5'] = 5; delta[5]['6'] = 5;         delta[5]['7'] = 5;
        delta[5]['8'] = 5; delta[5]['9'] = 5; delta[5][':'] = 6;         delta[5][128] = 0;
        delta[6][' '] = 6;

        // Re[4] case:
        delta[4]['['] = 7;
        delta[7]['0'] = 7; delta[7]['1'] = 7; delta[7]['2'] = 7;         delta[7]['3'] = 7;
        delta[7]['4'] = 7; delta[7]['5'] = 7; delta[7]['6'] = 7;         delta[7]['7'] = 7;
        delta[7]['8'] = 7; delta[7]['9'] = 7; delta[7][':'] = 6;         delta[7][128] = 0;
        delta[7][']'] = 8;
        delta[8][':'] = 6; delta[8][128] = 0;

        // German Outlook (not in diagram below)
        delta[2]['A'] = 9;
        delta[9]['W'] = 4; delta[9][128] = 0;
        delta[2]['W'] = 10;
        delta[10]['G'] = 4; delta[10][128] = 0;
        }

    n = [self length];
    i = 1;
    do {
        i--;
        lastMatch = i;
        // state == 0:  failure, state == 1 : success
        for (state = 2; (i < n) && (state > 1); i++)
            {
            c = (unsigned int)[self characterAtIndex:i];
            state = delta[state][MIN(c, 128)];
            }
    } while ((state == 1) && (i < n)); // match multiple times

    return lastMatch ? [self substringFromIndex: lastMatch] : self;
}


/*
                                    digit      space
                                    /	\      /   \ 	
         R,r        E,e         ^   \   /   :  \   /
    (2) -----> (3) -----> (4) -----> (5) -----> (6) -----> ((1))
                           |\___________________/
                           |          :        /
                           \                  / :
                            \----> (7) ---> (8)
                               [   / \  ]
                                   \ /
                                  digit
 */


//---------------------------------------------------------------------------------------
//	CONVERSIONS
//---------------------------------------------------------------------------------------

- (NSString*) stringByApplyingROT13
{
	NSString	 	*result;
	unsigned int 	length, i;
	unichar			*buffer, *cp;

	length = [self length];
	buffer = NSZoneMalloc([self zone], length * sizeof(unichar));
	[self getCharacters:buffer range:NSMakeRange(0, length)];
	for(i = 0, cp = buffer; i < length; i++, cp++)
		if((*cp >= (unichar)'a') && (*cp <= (unichar)'z'))
			*cp = (((*cp - 'a') + 13) % 26) + 'a';
		else if((*cp >= (unichar)'A') && (*cp <= (unichar)'Z'))
			*cp = (((*cp - 'A') + 13) % 26) + 'A';
	result = [NSString stringWithCharacters:buffer length:length];
	NSZoneFree([self zone], buffer);
	
	return result;
}


//---------------------------------------------------------------------------------------
//	REFORMATTING
//---------------------------------------------------------------------------------------

- (NSString*) stringByUnwrappingParagraphs
{
    NSCharacterSet	*forceBreakSet, *separatorSet;
    NSMutableString	*buffer;
    NSEnumerator* lineEnum;
    NSString* lineBreakSeq, *currentLine, *nextLine;

    lineBreakSeq = @"\r\n";
    if([self rangeOfString:lineBreakSeq].length == 0)
        lineBreakSeq = @"\n";
    
    separatorSet = [NSCharacterSet characterSetWithCharactersInString: @" -\t"];
    forceBreakSet = [NSCharacterSet characterSetWithCharactersInString: @" \t.?!:-∑1234567890>}#%|"];
    buffer = [[[NSMutableString allocWithZone:[self zone]] init] autorelease];
    lineEnum = [[self componentsSeparatedByString:lineBreakSeq] objectEnumerator];
    currentLine = [lineEnum nextObject];
    while((nextLine = [lineEnum nextObject]) != nil)
        {
        [buffer appendString:currentLine];
		// if any of these conditions is met we don't unwrap
        if(([currentLine isEqualToString: @""]) || ([nextLine isEqualToString: @""]) || ([currentLine length] < 55) || ([forceBreakSet characterIsMember:[nextLine characterAtIndex:0]]))
            {
            [buffer appendString:lineBreakSeq];
            }
		// if the line didn't end with a whitespace or hyphen we insert a space
        else if([separatorSet characterIsMember:[currentLine characterAtIndex:[currentLine length] - 1]] == NO)
            {
            [buffer appendString: @" "];
            }
        currentLine = nextLine;
        }
    [buffer appendString:currentLine];

    return buffer;
}

- (NSString *)stringByWrappingToLineLength:(unsigned int)length
{
    NSCharacterSet	*breakSet, *textSet;
    NSMutableString	*buffer;
    NSEnumerator* lineEnum;
    NSString* lineBreakSeq, *originalLine, *prefix, *spillOver, *lastPrefix;
	NSMutableString	*mcopy;
    NSRange			textStart, endOfLine;
    unsigned int	lineStart, nextLineStart, prefixLength;

    lineBreakSeq = @"\r\n";
    if([self rangeOfString:lineBreakSeq].length == 0)
        lineBreakSeq = @"\n";

    breakSet = [NSCharacterSet characterSetWithCharactersInString:@" \t-"];
    textSet = [[NSCharacterSet characterSetWithCharactersInString:@" \t>}#%|"] invertedSet];
    buffer = [[[NSMutableString allocWithZone:[self zone]] init] autorelease];
	spillOver = nil; lastPrefix = nil; // keep compiler happy...
    lineEnum = [[self componentsSeparatedByString:lineBreakSeq] objectEnumerator];
    while((originalLine = [lineEnum nextObject]) != nil)
        {
		if((textStart = [originalLine rangeOfCharacterFromSet:textSet]).length == 0)
			textStart.location = [originalLine length];
		prefix = [originalLine substringToIndex:textStart.location];
		prefixLength = textStart.location;
		lineStart = textStart.location;		
				
		if(spillOver != nil)
            {
			if(([lastPrefix isEqualToString:prefix] == NO) || (textStart.length == 0))
				{
                [buffer appendString:lastPrefix];
                [buffer appendString:spillOver];
                [buffer appendString:lineBreakSeq];
				}
			else
				{
				originalLine = mcopy = [[originalLine mutableCopy] autorelease];
				[mcopy insertString: @" " atIndex:lineStart];
				[mcopy insertString:spillOver atIndex:lineStart];
				}
            }
		// note that this doesn't work properly if length(prefix) > length!, so...
		NSAssert(prefixLength <= length, @"line prefix too long.");
	
		if([originalLine length] - lineStart  > length - prefixLength)
			{
			do
            	{
				endOfLine = [originalLine rangeOfCharacterFromSet:breakSet options:NSBackwardsSearch range:NSMakeRange(lineStart, length - prefixLength)];
           		if(endOfLine.length > 0)
                	{
                	if([originalLine characterAtIndex:endOfLine.location] == (unichar)'-')
                    	endOfLine.location += 1;
                	nextLineStart = endOfLine.location;
                	while((nextLineStart < [originalLine length]) && ([originalLine characterAtIndex:nextLineStart] == (unichar)' '))
                    	nextLineStart += 1;
                	}
            	else
                	{
                	endOfLine = [originalLine rangeOfComposedCharacterSequenceAtIndex:lineStart + length - prefixLength];
                	nextLineStart = endOfLine.location;
                	}
                [buffer appendString:prefix];
                [buffer appendString:[originalLine substringWithRange:NSMakeRange(lineStart, endOfLine.location - lineStart)]];
                [buffer appendString:lineBreakSeq];
            	lineStart = nextLineStart;
				}
			while([originalLine length] - lineStart  > length - prefixLength);
            spillOver = [originalLine substringFromIndex:lineStart];
			}
		else
			{
			[buffer appendString:originalLine];
           	[buffer appendString:lineBreakSeq];
			spillOver = nil;
			}
		lastPrefix = prefix;
        }
	if(spillOver != nil)
        {
        [buffer appendString:lastPrefix];
        [buffer appendString:spillOver];
        [buffer appendString:lineBreakSeq];
        }

    return buffer;
}


- (NSString*) stringByPrefixingLinesWithString: (NSString*) prefix
{
    NSMutableString *buffer;
    NSEnumerator* lineEnum;
    NSString* lineBreakSeq, *line;

    lineBreakSeq = @"\r\n";
    if([self rangeOfString:lineBreakSeq].length == 0)
        lineBreakSeq = @"\n";

    buffer = [[[NSMutableString allocWithZone:[self zone]] init] autorelease];
    lineEnum = [[self componentsSeparatedByString:lineBreakSeq] objectEnumerator];
    while((line = [lineEnum nextObject]) != nil)
        {
        [buffer appendString:prefix];
        [buffer appendString:line];
        [buffer appendString:lineBreakSeq];
        }
    
    return buffer;
}


/*" Returns a folded version of the receiver according to RFC 2822 to the hard limit length. "*/

- (NSString*) stringByFoldingToLimit:(unsigned int)limit
{
    NSMutableString *result;
    NSCharacterSet *whitespaces;
    int lineStart;
    
    // short cut a very common case
    if ([self length] <= limit) return self;
    
    result = [NSMutableString string];
    whitespaces = [NSCharacterSet whitespaceCharacterSet];
    lineStart = 0;
    
    while (lineStart < [self length])
    {
        if (([self length] - lineStart) > limit) // something to fold left over?
        {
            NSRange lineEnd;
            
            // find place to fold:
            lineEnd = [self rangeOfCharacterFromSet:whitespaces options:NSBackwardsSearch range:NSMakeRange(lineStart, limit)];
            
            if (lineEnd.location == NSNotFound) // no whitespace found -> use hard break
            {
                lineEnd.location = lineStart + limit;
            }
            
            [result appendString:[self substringWithRange:NSMakeRange(lineStart, lineEnd.location - lineStart)]];
            [result appendString: @"\r\n "];
            
            lineStart = NSMaxRange(lineEnd);
        }
        else
        {
            [result appendString:[self substringWithRange:NSMakeRange(lineStart, [self length] - lineStart)]];
            
            break; // nothing to do in loop
        }
    }
    
    return [[result copy] autorelease];
}


/* eriks version?
/" Returns an unfolded version of the receiver according to RFC 2822 "/

- (NSString*) stringByUnfoldingString
{
    NSMutableString *result;
    NSString *CRLFSequence = @"\r\n";
    NSCharacterSet *whitespaces;
    int position;

    whitespaces = [NSCharacterSet whitespaceCharacterSet];
    result = [NSMutableString string];

    position = 0;
    while (position < [self length])
        {
        NSRange range;

        range = [self rangeOfString:CRLFSequence options: NULL range:NSMakeRange(position, [self length] - position)];

        if (range.location == NSNotFound)
            {
            [result appendString:[self substringWithRange:NSMakeRange(position, [self length] - position)]];
            break;
            }

        [result appendString:[self substringWithRange:NSMakeRange(position, range.location - position)]];

        if ((range.location + 2 >= [self length]) || (! [whitespaces characterIsMember:[self characterAtIndex:range.location + 2]]))
            {
            [result appendString:CRLFSequence];
            }
        position = range.location + 2;
        }
    return [result copy];
}
*/

+ (NSString*) temporaryFilename
{
	return [self temporaryFilenameWithPrefix: @"OPMessage"];
}

- (NSString *)realnameFromEMailStringWithFallback 
{
    NSString *realname = [self realnameFromEMailString];
    return [realname length] ? realname : self;
}

- (NSAttributedString *)attributedStringWithQuotationAttributes
/*"Removes quotation chars at the beginning of lines and add the quotation attribute to the corresponding lines."*/
{
    static NSCharacterSet *quoteCharSet = nil;
    
    NSMutableAttributedString *result;
    NSAutoreleasePool *pool;
    NSString* lineBreakSeq, *line;
    NSArray* lines;
    NSMutableArray *ranges;
    NSEnumerator *enumerator;
    NSArray *rangeObject;
    
    result = [[[NSMutableAttributedString alloc] init] autorelease];
    pool = [[NSAutoreleasePool alloc] init];
    
    lineBreakSeq = @"\r\n";
//    if([self rangeOfString:lineBreakSeq].length == 0)
//        lineBreakSeq = @"\n";
    
    if (! quoteCharSet) // singleton
        quoteCharSet = [[NSCharacterSet characterSetWithCharactersInString: @">"] retain];
    
    ranges = [NSMutableArray array];
    
    lines = [[self stringWithCanonicalLinebreaks] componentsSeparatedByString:lineBreakSeq];
    
    enumerator = [lines objectEnumerator];
    while (line = [enumerator nextObject])
    {
        int length;
        
        length = [line length];
        
        if ( (length > 0) 
            && ([quoteCharSet characterIsMember:[line characterAtIndex:0]]) ) // quote detected
        {
            int quoteDepth = 1, pos = 1;
            NSRange range;
            NSNumber *excerptDepth;

            // ##TODO axel->all room for improvement
            while ( (length > pos) 
                && ( ([quoteCharSet characterIsMember:[line characterAtIndex:pos]]) || ([line characterAtIndex:pos] == ' ') ) )
            {
                if ([line characterAtIndex:pos] != ' ')
                {
                    quoteDepth += 1;
                }
                
                pos += 1;
            }
            
            line = [line substringFromIndex:pos];
            range = NSMakeRange([result length], [line length] + [lineBreakSeq length]);

            [result appendString:line];
            [result appendString:lineBreakSeq];
                        
            excerptDepth = [NSNumber numberWithInt:quoteDepth];
            
            
            if (excerptDepth)
            {
                //[ranges addObject:[OPObjectPair pairWithObjects:[EDRange rangeWithRangeValue:range] :excerptDepth]];
                [ranges addObject:[NSArray arrayWithObjects:NSStringFromRange(range), excerptDepth, nil]];
            }
        }
        else
        {
            [result appendString:line];
            [result appendString:lineBreakSeq];
        }
    }
    
    // setting the attribute
    enumerator = [ranges objectEnumerator];
    while (rangeObject = [enumerator nextObject])
    {
        NSRange range;
        NSNumber *excerptDepth;
        
        range = NSRangeFromString([rangeObject objectAtIndex:0]);
        
        while (NSMaxRange(range) >= [result length])
        {
            range.length--;
        }
        excerptDepth = [rangeObject objectAtIndex:1];
    
        [result addAttribute:OPQuotationAttributeName value:excerptDepth range:range];
    }
    
    [pool release];

    [result fixAttributesInRange:NSMakeRange(0, [result length])];

    return result;
}

- (long)octalValue
{
    NSString *workString;
    int i, length;
    long result = 0;
    NSAutoreleasePool *pool;
    
    pool = [[NSAutoreleasePool alloc] init];
    
    workString = [self stringByRemovingSurroundingWhitespace];
    length = [workString length];
    
    for (i = 0; i < length; i++)
    {
        int digit;
        
        digit = [[workString substringWithRange:NSMakeRange(i, 1)] intValue];
        
        NSAssert(digit < 8, @"Octal string contains illegal digits.");
        
        result = (result << 3);	// one octal shift
        result += digit;
    }
    
    [pool release];
    
    return result;
}

+ (NSString *)xUnixModeString:(int)aNumber
{
    NSMutableString *result;
    
    result = [NSMutableString string];
    
    // 1st
    [result appendFormat: @"%d", aNumber / 01000];
    aNumber %= 01000;
    [result appendFormat: @"%d", aNumber / 0100];
    aNumber %= 0100;
    [result appendFormat: @"%d", aNumber / 010];
    aNumber %= 010;
    [result appendFormat: @"%d", aNumber / 01];

    return result;
}

- (NSCalendarDate *)dateFromRFC2822String
/*"
Attempts to parse a date according to the rules in RFC 2822. However, some mailers don't follow that format as specified, so dateFromRFC2822String tries to guess correctly in such cases. The receiver is a string containing an RFC 2822 date, such as 'Mon, 20 Nov 1995 19:12:08 -0500'. If it succeeds in parsing the date, dateFromRFC2822String returns a NSCalendarDate. nil otherwise.
"*/
{
    const char *lossyCString;
    char *dateString;
    char *dayString;
    char *monthString;
    char *yearString;
    char *timeString;
    char *timezoneString;
    char *dateStringToken;
    char *lowerPtr;
    char *help;
    int length;
    char lastChar;
    const char **monthnamesPtr;
    int month, day, year, thh, tmm, tss;
    NSTimeZone *timezone = nil;
        
    static const char *monthnames[] = {
                "jan", "feb", "mar", "apr", "may", "jun", "jul",
                "aug", "sep", "oct", "nov", "dec",
                "january", "february", "march", "april", "may", "june", "july",
                "august", "september", "october", "november", "december",
                NULL}; 
    static const char *daynames[] = {
                "mon", "tue", "wed", "thu", "fri", "sat", "sun",
                NULL}; 
    
    // get the string to work on
    if ( (lossyCString = [self UTF8String]) == NULL)
        return nil;
    if ( (dateString = malloc(strlen(lossyCString) + 1)) == NULL)
        return nil;
    strcpy(dateString, lossyCString);
    
    // ### Remove day names at the beginning if present
    // get first token
    do
    {
        if( (dateStringToken = strtok(dateString, " -")) == NULL)
        {
            free(dateString);
            return nil;
        }
    } while (dateStringToken[0] == '\0'); // dont accept empty strings
    
    // get last char
    length = strlen(dateStringToken);
    lastChar = dateStringToken[length - 1];

    if ((lastChar == ',') || (lastChar == '.'))
    {
        // skip this token
        do
        {
            if( (dateStringToken = strtok(NULL, " -")) == NULL)
            {
                free(dateString);
                return nil;
            }
        } while (dateStringToken[0] == '\0'); // dont accept empty strings
    }
    else // test if it's a day name
    {
        const char **daynamesPtr;
        
        // make lower case string;
        for (lowerPtr = dateStringToken; *lowerPtr != '\0'; lowerPtr++)
        {
            *lowerPtr = tolower(*lowerPtr);
        }
        
        for (daynamesPtr = daynames; *daynamesPtr != NULL; daynamesPtr++)
        {
            if (strcmp(*daynamesPtr, dateStringToken) == 0) // found day name
            {
                // skip this token
                do
                {
                    if( (dateStringToken = strtok(NULL, " -")) == NULL)
                    {
                        free(dateString);
                        return nil;
                    }
                } while (dateStringToken[0] == '\0'); // dont accept empty strings
            }
        }
    }
    
    // ## day
    dayString = dateStringToken;
    
    // next token
    do
    {
        if( (dateStringToken = strtok(NULL, " -")) == NULL) // month required
        {
            free(dateString);
            return nil;
        }
    } while (dateStringToken[0] == '\0'); // dont accept empty strings
    
    monthString = dateStringToken;
    
    // next token
    do
    {
        if( (dateStringToken = strtok(NULL, " ")) == NULL)  // year required
        {
            free(dateString);
            return nil;
        }
    } while (dateStringToken[0] == '\0'); // dont accept empty strings
    
    yearString = dateStringToken;
    
    // ## time
    // next token
    do
    {
        if( (dateStringToken = strtok(NULL, " +")) == NULL)
        {
            free(dateString);
            return nil;
        }
    } while (dateStringToken[0] == '\0'); // dont accept empty strings
    
    timeString = dateStringToken;

    // next token   
    for(;;)
    {     
        timezoneString = strtok(NULL, " ");
        
        if (timezoneString == NULL)
            break;
        if (strlen(timezoneString) > 0)
            break;
    }     
    
    // ## handle months
        
    // make lower case string;
    for (lowerPtr = monthString; *lowerPtr != '\0'; lowerPtr++)
    {
        *lowerPtr = tolower(*lowerPtr);
    }
    
    for (monthnamesPtr = monthnames; *monthnamesPtr != NULL; monthnamesPtr++)
    {
        if (strcmp(*monthnamesPtr, monthString) == 0) // found month name
	{
            break;
        }    
    }
    
    // month name not found?
    if (monthnamesPtr == NULL)
    {
        // swap day and month
        help = dayString;
        dayString = monthString;
        monthString = help;

        // make lower case string;
        for (lowerPtr = monthString; *lowerPtr != '\0'; lowerPtr++)
        {
            *lowerPtr = tolower(*lowerPtr);
        }

        // search again
        for (monthnamesPtr = monthnames; *monthnamesPtr != NULL; monthnamesPtr++)
        {
            if (strcmp(*monthnamesPtr, monthString) == 0) // found month name
            {
                break;
            }    
        }
        
        // still not found?
        if (monthnamesPtr == NULL)
        {
            free(dateString);
            return nil;
        }
    }
    
    // month found calculate month number
    month = ((monthnamesPtr - monthnames) + 1);
    if (month > 12)
    {
        month -= 12;
    }
    
    // ### handle day
    day = atoi(dayString);
    
    if ( (day == 0) || (day == INT_MAX) || (day == INT_MIN) )
    {
        free(dateString);
        return nil;
    }
    
    // ## handle year
    
    // test if year and time are swapped
    if (strchr(yearString, ':') != NULL) // they are swapped
    {
        help = yearString;
        yearString = timeString;
        timeString = help;
    }
    
    // test if timezone and year are swapped
    if (! isdigit(yearString[0]))
    {
        help = yearString;
        yearString = timezoneString;
        timezoneString = help;
    }

    if (! yearString)
    {
        free(dateString);
        return nil;
    }
    
    year = atoi(yearString);
    if (strlen(yearString) == 2) // handle 2 digit years gracefully
    {
        if (year > 69)
            year += 1900;
        else
            year += 2000;
    }
    
    if ( (year == 0) || (year == INT_MAX) || (year == INT_MIN) ) // sanity check
    {
        free(dateString);
        return nil;
    }

    // ## handle time
    
    thh = tmm = tss = 0;
    // hour
    if( (dateStringToken = strtok(timeString, ":")) != NULL)
    {
        thh = atoi(dateStringToken);
        
        if( (dateStringToken = strtok(NULL, ":")) != NULL)
        {
            tmm = atoi(dateStringToken);
            
            if( (dateStringToken = strtok(NULL, ":")) != NULL)
            {
                tss = atoi(dateStringToken);
            }
        }
        else
        {
            tmm = 0;
        }
    }
    
    // handle timezone
    if (timezoneString != NULL)
    {
        NSString *tz;
        
        tz = [[NSString alloc] initWithCString:timezoneString];
        timezone = [NSTimeZone timeZoneWithAbbreviation:tz];
        
        [tz release];
    }
    
    if (timezone == nil)
    {
        int timezoneOffset;
        int timezoneSign;
        
        if (timezoneString == NULL)
        {
            timezoneOffset = 0;
        }
        else
        {
            timezoneOffset = atoi(timezoneString);
            if (timezoneOffset < 0)
            {
                timezoneSign = -1;
                timezoneOffset *= -1;
            }
            else
            {
                timezoneSign = 1;
            }
        
            timezoneOffset = timezoneSign * ( (timezoneOffset/100)*3600 + (timezoneOffset % 100) * 60);
        }
        
        timezone = [NSTimeZone timeZoneForSecondsFromGMT:timezoneOffset];
        
        if (timezone == nil)
        {
            free(dateString);
            return nil;
        }
    }
    
    free(dateString);
    
    // calculate date
    return [NSCalendarDate dateWithYear:year month:month day:day hour:thh minute:tmm second:tss timeZone:timezone];
}

#ifdef _0
- (NSCalendarDate*) slowDateFromRFC2822String
/*"
Attempts to parse a date according to the rules in RFC 2822. However, some mailers don't follow that format as specified, so dateFromRFC2822String tries to guess correctly in such cases. Date is a string containing an RFC 2822 date, such as 'Mon, 20 Nov 1995 19:12:08 -0500'. If it succeeds in parsing the date, dateFromRFC2822String returns a NSDate. nil otherwise.
"*/
{
    NSMutableArray* dateStringComponents;
    NSString* dd;
	NSString* mm;
	NSString* yy;
	NSString* tm;
	NSString* tz;
    NSTimeZone* timezone;
    NSAutoreleasePool* pool;
    static NSArray* monthnames = nil;
    static NSArray* daynames = nil;
    int month, day, year, thh, tmm, tss;
    
    pool = [[NSAutoreleasePool alloc] init];
    
    if (monthnames == nil) // prepare "singletons"
    {
        monthnames = [[NSArray alloc] initWithObjects:
                @"jan", @"feb", @"mar", @"apr", @"may", @"jun", @"jul",
                @"aug", @"sep", @"oct", @"nov", @"dec",
                @"january", @"february", @"march", @"april", @"may", @"june", @"july",
                @"august", @"september", @"october", @"november", @"december", nil];
        daynames = [[NSArray alloc] initWithObjects:
                @"mon", @"tue", @"wed", @"thu", @"fri", @"sat", @"sun", nil];
    }
    
    dateStringComponents = [[[self componentsSeparatedByString: @" "] mutableCopy] autorelease];

    {
        // remove empty strings
        int i = 0;
        
        while (i < [dateStringComponents count])
        {
            NSString *component;
            
            component = [dateStringComponents objectAtIndex:i];
            if ([component isEqualToString: @""])
            {
                [dateStringComponents removeObjectAtIndex:i];
            }
            else
            {
                i++;
            }
        }
    }
    
    // Remove day names at the beginning if present
    {
        NSString *daynameCandidate;
        
        daynameCandidate = [dateStringComponents objectAtIndex:0];
        if ([daynameCandidate hasSuffix: @","]
            || [daynameCandidate hasSuffix: @"."]
            || [daynames containsObject:[daynameCandidate lowercaseString]]) {
            // There's a dayname here. Skip it
            [dateStringComponents removeObjectAtIndex:0];
        }
    }
        
    // RFC 850 date, deprecated
    if ([dateStringComponents count] == 3) {
        NSArray* rfc850DateComponents;
        
        rfc850DateComponents = [[dateStringComponents objectAtIndex:0] componentsSeparatedByString: @"-"];
        
        if ([rfc850DateComponents count] == 3) // it's most likely a RFC 820 date
        {
            [dateStringComponents insertObject:[rfc850DateComponents objectAtIndex:0] atIndex:0]; // day
            [dateStringComponents insertObject:[rfc850DateComponents objectAtIndex:1] atIndex:1]; // month
            [dateStringComponents insertObject:[rfc850DateComponents objectAtIndex:2] atIndex:2]; // year
        }
    }

    // fix when timezone is not space separated from time
    if ([dateStringComponents count] == 4)
    {
        NSString *suspect;
        NSRange rangeOfPlus;
        
        suspect = [dateStringComponents objectAtIndex:3];
        rangeOfPlus = [suspect rangeOfString: @"+" options:0 range:NSMakeRange(0, [suspect length])];
        if (rangeOfPlus.location != NSNotFound)
        {
            NSString *time;
            NSString *timezone;
            
            time = [suspect substringToIndex:rangeOfPlus.location];
            timezone = [suspect substringFromIndex:rangeOfPlus.location];
            
            [dateStringComponents replaceObjectAtIndex:3 withObject:time];
            [dateStringComponents addObject:timezone];
        }
        else
        {
            [dateStringComponents addObject: @""];
        }
    }
            
    // needs 5 components
    if ([dateStringComponents count] < 5)
    {
        [pool release];
        return nil;
    }

    while ([dateStringComponents count] > 5)
    {
        [dateStringComponents removeLastObject];
    }
    
    // grab vars
    dd = [dateStringComponents objectAtIndex:0];
    mm = [dateStringComponents objectAtIndex:1];
    yy = [dateStringComponents objectAtIndex:2];
    tm = [dateStringComponents objectAtIndex:3];
    tz = [dateStringComponents objectAtIndex:4];
         
    // handle months
    {
        int index;
        
        mm = [mm lowercaseString];
        index = [monthnames indexOfObject:mm];
        if (index == NSNotFound) // swap dd and mm
        {
            NSString *help;
            
            help = dd;
            dd = mm;
            mm = [help lowercaseString];
            
            index = [monthnames indexOfObject:mm];
            if (index == NSNotFound)
            {
                [pool release];
                return nil;
            }
        }
        month = (index + 1) % 12;
    }
    
    // handle day
    if ([dd hasSuffix: @","])
    {
        dd = [dd substringToIndex:[dd length] - 1]; // chop last character
    }
    
    day = [dd intValue];
    
    if ( (day == 0) || (day == INT_MAX) || (day == INT_MIN) )
    {
        [pool release];
        return nil;
    }
    
    // handle year
    {
        NSRange range;
        
        range = [yy rangeOfString: @":" options:0 range:NSMakeRange(0, [yy length])];
        if (range.location != NSNotFound) // swap year and time
        {
            NSString *help;
            
            help = yy;
            yy = tm;
            tm = help;
        }
        
        if ([yy hasSuffix: @","])
        {
            yy = [yy substringToIndex:[yy length] -1]; // chop last character
        }
        
        if (! isdigit((char)[yy characterAtIndex:0])) // swap time zone and year
        {
            NSString *help;
            
            help = yy;
            yy = tz;
            tz = help;
        }
        
        year = [yy intValue];
        if ([yy length] == 2)
        {
            if (year > 69)
                year += 1900;
            else
                year += 2000;
        }
        
        if ( (year == 0) || (year == INT_MAX) || (year == INT_MIN) )
        {
            [pool release];
            return nil;
        }
    }
    
    // handle time
    {
        NSArray* timeComponents;
        
        if ([tm hasSuffix: @","]) {
            tm = [tm substringToIndex:[tm length] - 1]; // chop last char
        }
    
        timeComponents = [tm componentsSeparatedByString: @":"];
        
        if ([timeComponents count] == 2) {
            thh = [[timeComponents objectAtIndex: 0] intValue];
            tmm = [[timeComponents objectAtIndex: 1] intValue];
            tss = 0;
        }
        else if ([timeComponents count] == 3)
        {
            thh = [[timeComponents objectAtIndex:0] intValue];
            tmm = [[timeComponents objectAtIndex:1] intValue];
            tss = [[timeComponents objectAtIndex:2] intValue];
        }
        else
        {
            thh = tmm = tss = 0;
        }
    }
    
    // handle timezone
    timezone = [NSTimeZone timeZoneWithAbbreviation:tz];
    
    if (timezone == nil)
    {
        int timezoneOffset;
        int timezoneSign;
        
        timezoneOffset = [tz intValue];
        if (timezoneOffset < 0)
        {
            timezoneSign = -1;
            timezoneOffset *= -1;
        }
        else
        {
            timezoneSign = 1;
        }
        
        timezoneOffset = timezoneSign * ( (timezoneOffset/100)*3600 + (timezoneOffset % 100) * 60);
        
        timezone = [NSTimeZone timeZoneForSecondsFromGMT:timezoneOffset];
        
        if (timezone == nil)
        {
            [pool release];
            return nil;
        }
    }
    
    // calculate date
    return [NSCalendarDate dateWithYear:year month:month day:day hour:thh minute:tmm second:tss timeZone:timezone];
}
#endif

- (NSString*) stringByNormalizingWhitespaces
{
    NSCharacterSet *whitespaceCharacterSet;
    NSScanner *scanner;
    NSMutableArray *components;
    NSString *result;

    whitespaceCharacterSet = [NSCharacterSet whitespaceCharacterSet];
    components = [[NSMutableArray allocWithZone:[self zone]] init];

    scanner = [[NSScanner allocWithZone:[self zone]] initWithString:self];
    [scanner setCharactersToBeSkipped:whitespaceCharacterSet];

    while(! [scanner isAtEnd])
    {
        NSAutoreleasePool *innerPool;
        NSString *component;

        innerPool = [[NSAutoreleasePool allocWithZone:[self zone]] init];

        if([scanner scanUpToCharactersFromSet:whitespaceCharacterSet intoString:&component])
            [components addObject:component];

        [innerPool release];
    }

    result = [components componentsJoinedByString: @" "];

    [components release];
    [scanner release];

    return result;
}

#ifdef _0
- (NSString*) stringByFoldingStringToLimit:(int)limit
/*" Returns a folded version of the receiver according to RFC 2822 to the hard limit  length. "*/
{
    // short cut a very common case
    if ([self length] <= limit) {
        return self;
    } else {
        NSMutableString *result;
        NSCharacterSet *whitespaces;
        int lineStart;

        result = [NSMutableString string];
        whitespaces = [NSCharacterSet whitespaceCharacterSet];
        lineStart = 0;

        while (lineStart < [self length]) {
            if (([self length] - lineStart) > limit)
                // something to fold left over?
            {
                NSRange lineEnd;
                
                // find place to fold
                lineEnd = [self rangeOfCharacterFromSet:whitespaces options:NSBackwardsSearch range:NSMakeRange(lineStart, limit)];

                if (lineEnd.location == NSNotFound) // no whitespace found -> use hard break
                {
                    lineEnd.location = lineStart + limit;
                }

                [result appendString:[self substringWithRange:NSMakeRange(lineStart, lineEnd.location - lineStart)]];
                [result appendString: @"\r\n "];
                
                lineStart = NSMaxRange(lineEnd);
            }
            else
            {
                [result appendString:[self substringWithRange:NSMakeRange(lineStart, [self length] - lineStart)]];

                break; // nothing to do in loop
            }
        }
        
        return [result copy];
    }
}
#endif

- (NSString*) stringByUnfoldingString
/*" Returns an unfolded version of the receiver according to RFC 2822 "*/
{
    NSMutableString *result;
    NSString *CRLFSequence = @"\r\n";
    NSCharacterSet *whitespaces;
    int position;

    whitespaces = [NSCharacterSet whitespaceCharacterSet];
    result = [NSMutableString string];

    position = 0;
    while (position < [self length]) {
        NSRange range = [self rangeOfString: CRLFSequence 
                                    options: 0 
                                      range: NSMakeRange(position, [self length] - position)];

        if (range.location == NSNotFound) {
            [result appendString:[self substringWithRange:NSMakeRange(position, [self length] - position)]];
            break;
        }

        [result appendString:[self substringWithRange:NSMakeRange(position, range.location - position)]];
        
        if ((range.location + 2 >= [self length]) || (! [whitespaces characterIsMember:[self characterAtIndex:range.location + 2]]))
        {
            [result appendString:CRLFSequence];
        }
        position = range.location + 2;
    }
    
    return [result copy];
}


- (NSArray *)fieldListFromEMailString 
{
    NSCharacterSet *stopSet, *quoteSet, *nonWhitespaceSet;
    NSString *chunk;
    NSScanner *scanner;
    NSMutableString *part;
    NSMutableArray *result;
    
    result = [NSMutableArray array];
    nonWhitespaceSet = [[NSCharacterSet whitespaceAndNewlineCharacterSet] invertedSet];
    stopSet = [NSCharacterSet characterSetWithCharactersInString: @"\","];
    quoteSet = [NSCharacterSet characterSetWithCharactersInString: @"\""];
    part = [[[NSMutableString allocWithZone:[self zone]] init] autorelease];
    scanner = [NSScanner scannerWithString:self];
    
    while([scanner isAtEnd] == NO)
    {
        if([scanner scanUpToCharactersFromSet:stopSet intoString:&chunk] == YES)
        {
            [part appendString:chunk];
        }
        if([scanner scanString: @"\"" intoString: NULL] == YES)
        {
            if([scanner scanUpToCharactersFromSet:quoteSet intoString:&chunk] == YES)
            {
                [part appendString: @"\""];
                [part appendString:chunk];
                [part appendString: @"\" "];
                [scanner scanString: @"\"" intoString: NULL];
            }
        }
        else
        {
            [scanner scanString: @"," intoString: NULL];
            [result addObject:[part stringByRemovingSurroundingWhitespace]];
            part = [[[NSMutableString allocWithZone:[self zone]] init] autorelease];
        }
    }
    
    return result;
}

- (NSArray *)addressWithRealnameListFromEMailString
{
    NSEnumerator *enumerator;
    NSString *field;
    NSMutableArray *result;
    
    result = [NSMutableArray array];
    
    enumerator = [[self fieldListFromEMailString] objectEnumerator];
    
    while (field = [enumerator nextObject])
    {
        field = [field stringByRemovingSurroundingWhitespace];
        
        if ([field length])
        {
            [result addObject:field];
        }
    }
    
    return result;
    /*
	 return [[[self fieldListFromEMailString] arrayByMappingWithSelector:@selector(stringByRemovingSurroundingWhitespace)] arrayByMappingWithSelector:@selector(addressFromEMailString)];
     */
}

- (NSArray *)addressListFromEMailString 
{
    NSEnumerator *enumerator;
    NSString *field;
    NSMutableArray *result;
    
    result = [NSMutableArray array];
    
    enumerator = [[self fieldListFromEMailString] objectEnumerator];
    
    while (field = [enumerator nextObject])
    {
        field = [field stringByRemovingSurroundingWhitespace];
        field = [field addressFromEMailString];
        
        if ([field length])
        {
            [result addObject:field];
        }
    }
    
    return result;
    /*
    return [[[self fieldListFromEMailString] arrayByMappingWithSelector:@selector(stringByRemovingSurroundingWhitespace)] arrayByMappingWithSelector:@selector(addressFromEMailString)];
     */
}

- (NSArray *)realnameListFromEMailString 
{
    NSEnumerator *enumerator;
    NSString *field;
    NSMutableArray *result;
    
    result = [NSMutableArray array];
    
    enumerator = [[self fieldListFromEMailString] objectEnumerator];
    
    while (field = [enumerator nextObject])
    {
        field = [field stringByRemovingSurroundingWhitespace];
        field = [field realnameFromEMailStringWithFallback];
        
        if ([field length])
        {
            [result addObject:field];
        }
    }
    
    return result;
}

- (NSString *)stringByWrappingToSoftLimit:(unsigned int)length
/*" Returns a wrapped version of the receiver to the soft limit. Soft limit means that the string can only be wrapped on whitespaces. "*/
{
    NSCharacterSet	*breakSet, *textSet;
    NSMutableString	*buffer;
    NSEnumerator* lineEnum;
    NSString* lineBreakSeq, *originalLine, *prefix, *spillOver, *lastPrefix;
    NSMutableString	*mcopy;
    NSRange			textStart, endOfLine;
    unsigned int	lineStart, nextLineStart, prefixLength;

    lineBreakSeq = @"\r\n";
    if([self rangeOfString:lineBreakSeq].location == NSNotFound)
	{
        lineBreakSeq = @"\n";
	}
	
    breakSet = [NSCharacterSet characterSetWithCharactersInString:@" "];
    textSet = [[NSCharacterSet characterSetWithCharactersInString:@""] invertedSet];
    buffer = [[[NSMutableString allocWithZone:[self zone]] init] autorelease];
    spillOver = nil; lastPrefix = nil; // keep compiler happy...
    lineEnum = [[self componentsSeparatedByString:lineBreakSeq] objectEnumerator];
    while((originalLine = [lineEnum nextObject]) != nil)
    {
        if((textStart = [originalLine rangeOfCharacterFromSet:textSet]).length == 0)
            textStart.location = [originalLine length];
        prefix = [originalLine substringToIndex:textStart.location];
        prefixLength = textStart.location;
        lineStart = textStart.location;

        if(spillOver != nil)
            if(([lastPrefix isEqualToString:prefix] == NO) || (textStart.length == 0))
            {
                [buffer appendString:lastPrefix];
                [buffer appendString:spillOver];
                [buffer appendString:lineBreakSeq];
            }
                else
                {
                    originalLine = mcopy = [[originalLine mutableCopy] autorelease];
//                    [mcopy insertString: @" " atIndex:lineStart];
                    [mcopy insertString:spillOver atIndex:lineStart];
                }

                // note that this doesn't work properly if length(prefix) > length!, so...
                NSAssert(prefixLength <= length, @"line prefix too long.");

        if([originalLine length] - lineStart  > length - prefixLength)
        {
            do
            {
                endOfLine = [originalLine rangeOfCharacterFromSet:breakSet options:NSBackwardsSearch range:NSMakeRange(lineStart, length - prefixLength)];
                if(endOfLine.length > 0)
                {
                    nextLineStart = endOfLine.location;
                    while((nextLineStart < [originalLine length]) && ([originalLine characterAtIndex:nextLineStart] == (unichar)' '))
                        nextLineStart += 1;
                }
                else // no blank break was found
                {
                    endOfLine = [originalLine rangeOfCharacterFromSet:breakSet options:0 range:NSMakeRange(lineStart + length, [originalLine length] - (lineStart + length))];

                    if(endOfLine.length > 0)
                    {
                        nextLineStart = endOfLine.location;
                        while((nextLineStart < [originalLine length]) && ([originalLine characterAtIndex:nextLineStart] == (unichar)' '))
                            nextLineStart += 1;
                    }
                    else
                    {
                        nextLineStart = endOfLine.location = [originalLine length];
                    }
                }
                [buffer appendString:prefix];
                [buffer appendString:[originalLine substringWithRange:NSMakeRange(lineStart, endOfLine.location - lineStart)]];
                [buffer appendString:lineBreakSeq];
                lineStart = nextLineStart;
            }
            while([originalLine length] - lineStart  > length - prefixLength);
            spillOver = [originalLine substringFromIndex:lineStart];
        }
        else
        {
            [buffer appendString:originalLine];
           	[buffer appendString:lineBreakSeq];
                spillOver = nil;
        }
        lastPrefix = prefix;
    }
    if(spillOver != nil)
    {
        [buffer appendString:lastPrefix];
        [buffer appendString:spillOver];
        [buffer appendString:lineBreakSeq];
    }


    if ([self hasSuffix:lineBreakSeq])
    {
        return buffer;
    } else {
        return [buffer substringToIndex:[buffer length] - [lineBreakSeq length]];
    }
}

- (NSString *)stringByEncodingFlowedFormatUsingDelSp:(BOOL)useDelSp
/*" RFC3676 "*/
{    
	NSString *normalizedString = [self stringWithCanonicalLinebreaks];
	
    NSString *lineBreakSeq = @"\r\n";
	/*
    if([normalizedString rangeOfString: lineBreakSeq].location == NSNotFound)
	{
        lineBreakSeq = @"\n";
    }
	*/
	
    NSMutableString *flowedText = [[[NSMutableString alloc] initWithCapacity:[normalizedString length]] autorelease];
    
    NSArray *paragraphs = [normalizedString componentsSeparatedByString:lineBreakSeq];
    
    NSEnumerator *paragraphEnumerator = [paragraphs objectEnumerator];
	NSString *paragraph;
	
    while ((paragraph = [paragraphEnumerator nextObject]) != nil) 
	{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        
        /*
         1.  Ensure all lines (fixed and flowed) are 79 characters 
		 (78 characters when DelSP is used) 
		 or fewer in length, counting the trailing space but not
         counting the CRLF, unless a word by itself exceeds 79
         characters.
         */
        
		// special handling of signature:
		if ([paragraph isEqualToString:@"-- "])
		{
			[flowedText appendString:paragraph];
			[flowedText appendString:lineBreakSeq];
			continue;
		}
		
        /*
         2.  Trim spaces before user-inserted hard line breaks.
         */
        while ([paragraph hasSuffix:@" "])
            paragraph = [paragraph substringToIndex:[paragraph length] - 1]; // chop the last character
        
        if ([paragraph length] > useDelSp ? 78 : 79) 
		{
            NSString *wrappedParagraph;
            NSArray *paragraphLines;
            int i, count;
            /*
             When creating flowed text, the generating agent wraps, that is,
             inserts 'soft' line breaks as needed.  Soft line breaks are added
             between words.  Because a soft line break is a SP CRLF sequence, the
             generating agent creates one by inserting a CRLF after the occurance
             of a space.
             */
            wrappedParagraph = [[[paragraph stringByAppendingString:lineBreakSeq] stringByWrappingToLineLength:998] stringByWrappingToSoftLimit:72];
            
            // chop lineBreakSeq at the end
			while ([wrappedParagraph hasSuffix:lineBreakSeq])
			{
				wrappedParagraph = [wrappedParagraph substringToIndex:[wrappedParagraph length] - [lineBreakSeq length]];
			}
			
            paragraphLines = [wrappedParagraph componentsSeparatedByString:lineBreakSeq];
            
            count = [paragraphLines count];  
						
            for (i = 0; i < count; i++) 
			{	
                NSString *line;
                
                line = [paragraphLines objectAtIndex:i];
												
                /*
                 3.  Space-stuff lines which start with a space, "From ", or ">".
                 */  
                line = [line stringBySpaceStuffing];
                
                if (i < (count-1) ) 
				{
					BOOL lineEndsWithSpace = [line hasSuffix:@" "];
					BOOL isHardWrappedLine = [line length] >= 998;
					
					// ensure soft-break:
                    if (!lineEndsWithSpace && !isHardWrappedLine) 
					{
                        line = [line stringByAppendingString:@" "];
                    }
					
					if (useDelSp)
					{
                        line = [line stringByAppendingString:@" "];
					}
                } 
				else 
				{
                    while ([line hasSuffix:@" "]) 
					{
                        line = [line substringToIndex:[line length] - 1]; // chop the last character (space)
                    }
                }
                [flowedText appendString:line];
                [flowedText appendString:lineBreakSeq];
            }
        }
        else
        {
            // add paragraph to flowedText
            /*
             3.  Space-stuff lines which start with a space, "From ", or ">".
             */  
            paragraph = [paragraph stringBySpaceStuffing];
            [flowedText appendString:paragraph];
            [flowedText appendString:lineBreakSeq];
        }
        
        [pool release];
    }
    
    // chop lineBreakSeq at the end
    return [flowedText substringToIndex:[flowedText length] - [lineBreakSeq length]];
}

- (NSString *)stringByDecodingFlowedFormatUsingDelSp:(BOOL)useDelSp
/*" See RFC3676. "*/
{
    NSMutableString *flowedText;
	NSMutableString *paragraph;
    NSArray *lines;
    NSString *line;
	NSString *lineBreakSeq;
    NSEnumerator *lineEnumerator;
    int paragraphQuoteDepth = 0;
    BOOL isFlowed;
    
    lineBreakSeq = @"\r\n";
    if([self rangeOfString:lineBreakSeq].location == NSNotFound) 
	{
        lineBreakSeq = @"\n";
    }
    
    flowedText = [[NSMutableString allocWithZone:[self zone]] initWithCapacity:[self length]];
    
    paragraph = [NSMutableString string];
    
    if ([self hasSuffix:lineBreakSeq]) 
	{
        lines = [[self substringToIndex:[self length] - [lineBreakSeq length]] componentsSeparatedByString:lineBreakSeq];
    } 
	else 
	{
        lines = [self componentsSeparatedByString:lineBreakSeq];
    }
    
    lineEnumerator = [lines objectEnumerator];
    
    while ((line = [lineEnumerator nextObject]))
    {
        NSAutoreleasePool *pool;
        int quoteDepth = 0;
        /*
         4.1.  Interpreting Format=Flowed
         
         If the first character of a line is a quote mark (">"), the line is
         considered to be quoted (see Section 4.5).  Logically, all quote
         marks are counted and deleted, resulting in a line with a non-zero
         quote depth, and content.  (The agent is of course free to display
                                     the content with quote marks or excerpt bars or anything else.)
         Logically, this test for quoted lines is done before any other tests
         (that is, before checking for space-stuffed and flowed).
         */
        
        pool = [[NSAutoreleasePool alloc] init];
        
        while ([line hasPrefix:@">"])
        {
            line = [line substringFromIndex:1]; // chop of the first character
            quoteDepth += 1;
        }
        
        if ((paragraphQuoteDepth == 0) && (quoteDepth != 0))
        {
            paragraphQuoteDepth = quoteDepth;
        }
        
        /*
         If the first character of a line is a space, the line has been
         space-stuffed (see section 4.4).  Logically, this leading space is
         deleted before examining the line further (that is, before checking
                                                    for flowed).   
         */
        
        if ([line hasPrefix:@" "])
        {
            line = [line substringFromIndex:1]; // chop of the first character
        }
        
        /*
         If the line ends in a space, the line is flowed.  Otherwise it is
         fixed.  The exception to this rule is a signature separator line,
         described in Section 4.3.  Such lines end in a space but are neither
         flowed nor fixed.
         */
        
        isFlowed = [line hasSuffix:@" "] 
            && (paragraphQuoteDepth == quoteDepth) 
            && ([line caseInsensitiveCompare: @"-- "] != NSOrderedSame);
        
        /*
         If the line is flowed and DelSp is "yes", the trailing space
         immediately prior to the line's CRLF is logically deleted.  If the
         DelSp parameter is "no" 
         (or not specified, or set to an unrecognized value), 
         the trailing space is not deleted.
         
         Any remaining trailing spaces are part of the line's content, but the
         CRLF of a soft line break is not. 
         */
        
        if (isFlowed && useDelSp)
        {
            line = [line substringToIndex:[line length] - 1];
        }
                
        /*
         A series of one or more flowed lines followed by one fixed line is
         considered a paragraph, and MAY be flowed (wrapped and unwrapped) as
         appropriate on display and in the construction of new messages 
         (see section 4.5).   
         */
        
        [paragraph appendString:line];
        if (! isFlowed)
        {
            if (paragraphQuoteDepth > 0) // add quote chars if needed
            {
                int i;
                
                for (i=0; i<paragraphQuoteDepth; i++)
                {
                    [flowedText appendString:@">"];
                }
                
                [flowedText appendString:@" "];
            }
            
            [flowedText appendString:paragraph];
            [flowedText appendString:lineBreakSeq];
            
            // reset values for next paragraph
            paragraphQuoteDepth = 0;
            [paragraph setString:@""];
        }
        
        [pool release];
    }
    
    // take care of the last paragraph
    if ([paragraph length] > 0)
    {
        if (paragraphQuoteDepth > 0) // add quote chars if needed
        {
            int i;
            
            for (i=0; i<paragraphQuoteDepth; i++)
            {
                [flowedText appendString:@">"];
            }
            
            [flowedText appendString:@" "];
        }
        
        [flowedText appendString:paragraph];
    }
    
    return [[flowedText autorelease] substringToIndex:[flowedText length] - [lineBreakSeq length]];
}

- (NSString *)stringBySpaceStuffing
{
    if (([self hasPrefix:@" "]) || ([self hasPrefix:@"From "]))
    {
        return [NSString stringWithFormat:@" %@", self];
    }
    
    return self;
}

- (NSString *)stringByStrippingTrailingWhitespacesAndNewlines 
{
    NSCharacterSet *whitespaceAndNewlineCharacterSet;
    int position;
    whitespaceAndNewlineCharacterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    
    position = [self length] - 1;
    
    if(position >= 0)
    {
        while( (position >= 0) && ([whitespaceAndNewlineCharacterSet characterIsMember:[self characterAtIndex:position]]) )
            position -= 1;
        
        return [self substringToIndex:position + 1];
    }
    else
        return self;
}

- (long)longValue 
{
    return atol([self UTF8String]);
}

- (NSString *)stringByRemovingAttachmentChars
{
    static NSCharacterSet *attachmentCharSet = nil;
    unichar attachmentChar = NSAttachmentCharacter;
    
    if (! attachmentCharSet) 
	{
        attachmentCharSet = [[NSCharacterSet characterSetWithCharactersInString:[NSString stringWithCharacters:&attachmentChar length:1]] retain];
    }
    
    return [self stringByRemovingCharactersFromSet:attachmentCharSet];
}

//---------------------------------------------------------------------------------------
    @end
//---------------------------------------------------------------------------------------



//---------------------------------------------------------------------------------------
    @implementation NSMutableString (OPMessageUtilities)
//---------------------------------------------------------------------------------------

- (void)appendAsLine:(NSString *)line withPrefix:(NSString *)prefix
{
	[self appendString:prefix];
	[self appendString:line];
	[self appendString:@"\n"];
}


//---------------------------------------------------------------------------------------
    @end
//---------------------------------------------------------------------------------------

/*
  * punycode.c from RFC 3492
  * http://www.nicemice.net/idn/
  * Adam M. Costello
  * http://www.nicemice.net/amc/
  *
  * This is ANSI C code (C89) implementing Punycode (RFC 3492).
  */
 
 #include <stdio.h>
 #include <stdlib.h>
 #include <limits.h>
 #include <string.h>
 
// #include "wattcp.h"
// #include "misc.h"
 #include "strings.h"

#define DWORD unichar
#define BYTE BOOL

enum punycode_status {
    punycode_success,
    punycode_bad_input,      /* Input is invalid.                       */
    punycode_big_output,     /* Output would exceed the space provided. */
    punycode_overflow        /* Input needs wider integers to process.  */
};

/*
 * punycode_encode() converts Unicode to Punycode.  The input
 * is represented as an array of Unicode code points 
 * (not code units; surrogate pairs are not allowed), and the output
 * will be represented as an array of ASCII code points.  The
 * output string is *not* null-terminated; it will contain
 * zeros if and only if the input contains zeros.  
 * (Of course the caller can leave room for a terminator and add one if needed.)
 * The input_length is the number of code points in
 * the input.  The output_length is an in/out argument: the
 * caller passes in the maximum number of code points that it
 * can receive, and on successful return it will contain the
 * number of code points actually output.  The case_flags array
 * holds input_length boolean values, where nonzero suggests that
 * the corresponding Unicode character be forced to uppercase
 * after being decoded (if possible), and zero suggests that
 * it be forced to lowercase (if possible).  ASCII code points
 * are encoded literally, except that ASCII letters are forced
 * to uppercase or lowercase according to the corresponding
 * uppercase flags.  If case_flags is a null pointer then ASCII
 * letters are left as they are, and other code points are
 * treated as if their uppercase flags were zero.  The return
 * value can be any of the punycode_status values defined above
 * except punycode_bad_input; if not punycode_success, then
 * output_size and output might contain garbage.
 */
enum punycode_status punycode_encode (DWORD input_length,
                                      const DWORD *input,
                                      const BYTE *case_flags,
                                      size_t *output_length,
                                      char *output);


/*
 * punycode_decode() converts Punycode to Unicode.  The input is
 * represented as an array of ASCII code points, and the output
 * will be represented as an array of Unicode code points.  The
 * input_length is the number of code points in the input.  The
 * output_length is an in/out argument: the caller passes in
 * the maximum number of code points that it can receive, and
 * on successful return it will contain the actual number of
 * code points output.  The case_flags array needs room for at
 * least output_length values, or it can be a null pointer if the
 * case information is not needed.  A nonzero flag suggests that
 * the corresponding Unicode character be forced to uppercase
 * by the caller (if possible), while zero suggests that it be
 * forced to lowercase (if possible).  ASCII code points are
 * output already in the proper case, but their flags will be set
 * appropriately so that applying the flags would be harmless.
 * The return value can be any of the punycode_status values
 * defined above; if not punycode_success, then output_length,
 * output, and case_flags might contain garbage.  On success, the
 * decoder will never need to write an output_length greater than
 * input_length, because of how the encoding is defined.
 */
enum punycode_status punycode_decode (DWORD input_length,
                                      const char *input,
                                      size_t *output_length,
                                      DWORD *output,
                                      BYTE *case_flags);

 /*** Bootstring parameters for Punycode ***/
 
 enum {
   base = 36, tmin = 1, tmax = 26,
   skew = 38, damp = 700,
   initial_bias = 72,
   initial_n = 0x80,
   delimiter = 0x2D
 };
 
 /* basic(cp) tests whether cp is a basic code point:
  */
 #define basic(cp) ((DWORD)(cp) < 0x80)
 
 /* delim(cp) tests whether cp is a delimiter:
  */
 #define delim(cp) ((cp) == delimiter)
 
 /*
  * decode_digit(cp) returns the numeric value of a basic code
  * point (for use in representing integers) in the range 0 to
  * base-1, or base if cp is does not represent a value.
  */
 static DWORD decode_digit (DWORD cp)
 {
   return (cp - 48 < 10 ?
           cp - 22 : cp - 65 < 26 ?
           cp - 65 : cp - 97 < 26 ?
           cp - 97 : base);
 }
 
 /*
  * encode_digit(d,flag) returns the basic code point whose value
  * (when used for representing integers) is d, which needs to be in
  * the range 0 to base-1.  The lowercase form is used unless flag is
  * nonzero, in which case the uppercase form is used.  The behavior
  * is undefined if flag is nonzero and digit d has no uppercase form.
  */
 static char encode_digit (DWORD d, int flag)
 {
   return (char) (d + 22 + 75 * (d < 26) - ((flag != 0) << 5));
   /*  0..25 map to ASCII a..z or A..Z */
   /* 26..35 map to ASCII 0..9         */
 }
 
 /* flagged(bcp) tests whether a basic code point is flagged
  * (uppercase).  The behavior is undefined if bcp is not a
  * basic code point.
  */
 #define flagged(bcp) ((DWORD)(bcp) - 65 < 26)
 
 /*
  * encode_basic(bcp,flag) forces a basic code point to lowercase
  * if flag is zero, uppercase if flag is nonzero, and returns
  * the resulting code point.  The code point is unchanged if it
  * is caseless.  The behavior is undefined if bcp is not a basic
  * code point.
  */
 static char encode_basic (DWORD bcp, int flag)
 {
   bcp -= (bcp - 97 < 26) << 5;
   return (char) (bcp + ((!flag && (bcp - 65 < 26)) << 5));
 }
 
 /* maxint is the maximum value of a DWORD variable:
  */
 static const DWORD maxint = (DWORD)-1;
 
 static DWORD adapt (DWORD delta, DWORD numpoints, int firsttime)
 {
   DWORD k;
 
   delta = firsttime ? delta / damp : delta >> 1;
   /* delta >> 1 is a faster way of doing delta / 2
    */
   delta += delta / numpoints;
 
   for (k = 0; delta > ((base - tmin) * tmax) / 2; k += base)
       delta /= base - tmin;
   return k + (base - tmin + 1) * delta / (delta + skew);
 }
 
 /*
  *Main encode function
  */
 enum punycode_status punycode_encode (DWORD input_length,
                                       const DWORD *input,
                                       const BYTE *case_flags,
                                       size_t *output_length,
                                       char *output)
 {
   DWORD n, delta, h, b, out, max_out, bias, j, m, q, k, t;
 
   /* Initialize the state: */
 
   n = initial_n;
   delta = out = 0;
   max_out = *output_length;
   bias = initial_bias;
 
   /* Handle the basic code points: */
   for (j = 0; j < input_length; ++j)
   {
     if (basic (input[j]))
     {
       if (max_out - out < 2)
          return (punycode_big_output);
       output[out++] = case_flags ? encode_basic (input[j], case_flags[j]) :
                                    (char)input[j];
     }
 #if 0
     else if (input[j] < n)
          return (punycode_bad_input);
     /* (not needed for Punycode with unsigned code points) */
 #endif
   }
 
   h = b = out;
 
   /* h is the number of code points that have been handled, b is the
    * number of basic code points, and out is the number of characters
    * that have been output.
    */
   if (b > 0)
      output[out++] = delimiter;
 
   /* Main encoding loop:
    */
   while (h < input_length)
   {
     /* All non-basic code points < n have been
      * handled already.  Find the next larger one:
      */
     for (m = maxint, j = 0; j < input_length; ++j)
     {
 #if 0
       if (basic(input[j]))
           continue;
       /* (not needed for Punycode) */
 #endif
       if (input[j] >= n && input[j] < m)
          m = input[j];
     }
 
     /* Increase delta enough to advance the decoder's
      * <n,i> state to <m,0>, but guard against overflow:
      */
     if (m - n > (maxint - delta) / (h + 1))
        return (punycode_overflow);
 
     delta += (m - n) * (h + 1);
     n = m;
 
     for (j = 0; j < input_length; ++j)
     {
       if (input[j] < n)
       {
         if (++delta == 0)
            return (punycode_overflow);
       }
 
       if (input[j] == n)
       {
         /* Represent delta as a generalized variable-length integer:
          */
         for (q = delta, k = base;; k += base)
         {
           if (out >= max_out)
              return (punycode_big_output);
 
           t = k <= bias ? tmin :
               k >= bias + tmax ? tmax :
               k - bias;
           if (q < t)
              break;
           output[out++] = encode_digit (t + (q - t) % (base - t), 0);
           q = (q - t) / (base - t);
         }
         output[out++] = encode_digit (q, case_flags && case_flags[j]);
         bias = adapt (delta, h + 1, h == b);
         delta = 0;
         ++h;
       }
     }
     ++delta;
     ++n;
   }
 
   *output_length = out;
   return (punycode_success);
 }
 
 /*** Main decode function ***/
 
 enum punycode_status punycode_decode (DWORD input_length,
                                       const char *input,
                                       size_t *output_length,
                                       DWORD *output,
                                       BYTE *case_flags)
 {
   DWORD n, out, i, max_out, bias, b, j, in, oldi, w, k, digit, t;
 
   /* Initialize the state: */
 
   n = initial_n;
   out = i = 0;
   max_out = *output_length;
   bias = initial_bias;
 
/* Handle the basic code points:  Let b be the number of input code
    * points before the last delimiter, or 0 if there is none, then
    * copy the first b code points to the output.
    */
   for (b = j = 0; j < input_length; ++j)
       if (delim (input[j]))
          b = j;
   if (b > max_out)
      return (punycode_big_output);
 
   for (j = 0; j < b; ++j)
   {
     if (case_flags)
        case_flags[out] = flagged (input[j]);
     if (!basic (input[j]))
        return (punycode_bad_input);
     output[out++] = input[j];
   }
 
   /* Main decoding loop:  Start just after the last delimiter if any
    * basic code points were copied; start at the beginning otherwise.
    */
   for (in = b > 0 ? b + 1 : 0; in < input_length; ++out)
   {
     /* in is the index of the next character to be consumed, and
      * out is the number of code points in the output array.
      */
 
     /* Decode a generalized variable-length integer into delta,
      * which gets added to i.  The overflow checking is easier
      * if we increase i as we go, then subtract off its starting
      * value at the end to obtain delta.
      */
     for (oldi = i, w = 1, k = base;; k += base)
     {
       if (in >= input_length)
          return (punycode_bad_input);
 
       digit = decode_digit (input[in++]);
       if (digit >= base)
          return (punycode_bad_input);
 
       if (digit > (maxint - i) / w)
          return (punycode_overflow);
 
       i += digit * w;
       t = k <= bias ? tmin :
           k >= bias + tmax ? tmax :
           k - bias;
       if (digit < t)
          break;
       if (w > maxint / (base - t))
          return (punycode_overflow);
 
       w *= (base - t);
     }
 
     bias = adapt (i - oldi, out + 1, oldi == 0);
 
     /* i was supposed to wrap around from out+1 to 0,
      * incrementing n each time, so we'll fix that now:
      */
     if (i / (out + 1) > maxint - n)
        return (punycode_overflow);
 
     n += i / (out + 1);
     i %= (out + 1);
 
     /* Insert n at position i of the output:
      */
 #if 0
     /* not needed for Punycode: */
     if (decode_digit(n) <= base)
        return (punycode_invalid_input);
 #endif
     if (out >= max_out)
        return (punycode_big_output);
 
     if (case_flags)
     {
       memmove (case_flags + i + 1, case_flags + i, out - i);
 
       /* Case of last character determines uppercase flag:
        */
       case_flags[i] = flagged (input[in - 1]);
     }
     memmove (output + i + 1, output + i, (out - i) * sizeof *output);
     output[i++] = n;
   }
 
   *output_length = out;
   return (punycode_success);
 }


@implementation NSString (OPPunycode)

- (NSString *)punycodeDecodedString
/*" Assumes that the receiver contains a punycode encoded string (RFC 3492). Returns the content string in decoded form. Raises an exception if an error occurs. See punycode.h for error codes. 

    Note: For IDNs please use the -IDNA... methods."*/
{
    const char *input;
    DWORD input_length;
    size_t output_length = 256;
    DWORD output[256];
    enum punycode_status status;
    NSString *result;
    
    input = [self UTF8String];
    input_length = strlen(input);
    
    status = punycode_decode(input_length,
                             input,
                             &output_length,
                             output,
                             NULL);
    
    switch (status)
    {
        case punycode_bad_input:
        case punycode_big_output:
        case punycode_overflow:
            [NSException raise:NSGenericException format:@"Punycode decode error %d.", status];
            break;
        case punycode_success:
        default:
            break;
    }
    
    result = [NSString stringWithCharacters:output length:output_length];
    
    return result;
}

- (NSString *)punycodeEncodedString
/*" Returns the receiver's content string in punycode encoded form (RFC 3492). Raises an exception if an error occurs. See punycode.h for error codes. 

    Note: For IDNs please use the -IDNA... methods."*/
{
    DWORD input_length;
    size_t output_length = 256;
    char output[256];
    enum punycode_status status;
    unichar input[256];
    
    input_length = MIN(256, [self length]);
    [self getCharacters:input range:NSMakeRange(0, input_length)];
        
    status = punycode_encode(input_length,
                             input,
                             NULL,
                             &output_length,
                             output);
        
    switch (status)
    {
        case punycode_bad_input:
        case punycode_big_output:
        case punycode_overflow:
            [NSException raise:NSGenericException format:@"Punycode encode error %d.", status];
            break;
        case punycode_success:
        default:
            break;
    }
    
    return [[[NSString alloc] initWithCString:output length:output_length] autorelease];
}

- (NSString *)IDNADecodedDomainName
/*" Returns the receiver's content string in IDNA decoded form (RFC 3490). Shouldn't do any harm on domain names that are not IDNA encoded. If the receivers contents don't need decoding the receiver is returned. Raises an exception if an error occurs. See punycode.h for error codes."*/
{
    NSMutableArray *components;
    int i;
    BOOL decodingNeeded = NO;
    
    components = [[[self componentsSeparatedByString:@"."] mutableCopy] autorelease];
    
    for (i = [components count] - 1; i >= 0; i--)
    {
        NSString *component;
        
        component = [components objectAtIndex:i];
        
        if (([component length] > 4) && ([[component substringToIndex:4] caseInsensitiveCompare:@"xn--"] == NSOrderedSame))
        {
            [components replaceObjectAtIndex:i withObject:[[component substringFromIndex:4] punycodeDecodedString]];
            decodingNeeded = YES;
        }
    }
    
    return decodingNeeded ? [components componentsJoinedByString:@"."] : self;
}

- (NSString *)IDNAEncodedDomainName
/*" Returns the receiver's content string in IDNA encoded form (RFC 3490). Shouldn't do any harm on domain names that do not need IDNA encoding. If the receivers contents don't need encoding the receiver is returned. Raises an exception if an error occurs. See punycode.h for error codes."*/
{
    NSMutableArray *components;
    int i;
    BOOL decodingNeeded = NO;
    
    components = [[[self componentsSeparatedByString:@"."] mutableCopy] autorelease];
    
    for (i = [components count] - 1; i >= 0; i--)
    {
        NSString *component;
        
        component = [components objectAtIndex:i];
        
        if (! [component canBeConvertedToEncoding:NSASCIIStringEncoding])
        {
            [components replaceObjectAtIndex:i withObject:[@"xn--" stringByAppendingString:[component punycodeEncodedString]]];
            decodingNeeded = YES;
        }
    }
    
    return decodingNeeded ? [components componentsJoinedByString:@"."] : self;
}

@end
