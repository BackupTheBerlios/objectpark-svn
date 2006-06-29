//---------------------------------------------------------------------------------------
//  EDTextContentCoder.m created by erik on Fri 12-Nov-1999
//  @(#)$Id: EDTextContentCoder.m,v 1.3 2005/03/25 23:39:34 theisen Exp $
//
//  Copyright (c) 1997-2000 by Erik Doernenburg. All rights reserved.
//  Copyright (c) 2004 by Axel Katerbau & Dirk Theisen. All rights reserved.
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

#import <AppKit/AppKit.h>
#import "NSString+MessageUtils.h"
#import "EDMessagePart.h"
#import "EDTextContentCoder.h"
#import "OPObjectPair.h"
#import "NSArray+Extensions.h"
#import "NSAttributedString+Extensions.h"
#import "NSAttributedString+MessageUtils.h"
#import "OPInternetMessage.h"
#import "GIMessage+Rendering.h"
#import <OPDebug/OPLog.h>

#define EDTEXTCONTENTCONTROLLER OPL_DOMAIN @"EDTEXTCONTENTCONTROLLER"

@interface EDTextContentCoder(PrivateAPI)
- (NSString*) _stringFromMessagePart: (EDMessagePart*) mpart;
- (void) _takeTextFromPlainTextMessagePart: (EDMessagePart*) mpart;
- (void) _takeTextFromEnrichedTextMessagePart: (EDMessagePart*) mpart;
- (void) _takeTextFromHTMLMessagePart: (EDMessagePart*) mpart;
@end


//---------------------------------------------------------------------------------------
    @implementation EDTextContentCoder
//---------------------------------------------------------------------------------------

//---------------------------------------------------------------------------------------
//	CAPABILITIES
//---------------------------------------------------------------------------------------

+ (BOOL)canDecodeMessagePart: (EDMessagePart*) mpart
{
    NSString* type = [mpart contentType];
    
    if (![type hasPrefix: @"text/"]) return NO;

    NSString* charset = [[mpart contentTypeParameters] objectForKey: @"charset"];
    if((charset != nil) && ([NSString stringEncodingForMIMEEncoding:charset] == 0))
        return NO;

    if([type isEqualToString: @"text/plain"] || [type isEqualToString: @"text/enriched"] || [type isEqualToString: @"text/html"])
        return YES;

    return NO;
}


//---------------------------------------------------------------------------------------
//	INIT & DEALLOC
//---------------------------------------------------------------------------------------

- (id) initWithMessagePart: (EDMessagePart*) mpart
{
    if (self = [super init]) {
		part = [mpart retain];
    }
    return self;
}


- (void) dealloc
{
    [text release]; text = nil;
    [part release]; part = nil;
    [super dealloc];
}


//---------------------------------------------------------------------------------------
//	ATTRIBUTES
//---------------------------------------------------------------------------------------

- (NSAttributedString*) text
{
	if (!text) {
		// Create text lazily:
		NSString* type = [part contentType];

		if([type hasPrefix: @"text/"]) {
            if([type isEqualToString: @"text/plain"])
                [self _takeTextFromPlainTextMessagePart: part];
            else if([type isEqualToString: @"text/enriched"])
                [self _takeTextFromEnrichedTextMessagePart: part];
            else if([type isEqualToString: @"text/html"])
                [self _takeTextFromHTMLMessagePart: part];
        }	
	}
    return text;
}


//---------------------------------------------------------------------------------------
//	DECODING
//---------------------------------------------------------------------------------------

- (NSString*) _stringFromMessagePart: (EDMessagePart*) mpart
{
    NSString			*charset;
    NSStringEncoding	textEncoding;

    if((charset = [[mpart contentTypeParameters] objectForKey: @"charset"]) == nil)
        charset = MIMEAsciiStringEncoding;
    if((textEncoding = [NSString stringEncodingForMIMEEncoding:charset]) > 0)
        return [NSString stringWithData:[mpart contentData] encoding:textEncoding];
    return nil;
}


- (void) _takeTextFromPlainTextMessagePart: (EDMessagePart*) mpart
{
    NSString *string;
    
    if((string = [self _stringFromMessagePart:mpart]) != nil)
        text = [[NSAttributedString allocWithZone:[self zone]] initWithString:string];
}


- (void) _takeTextFromEnrichedTextMessagePart: (EDMessagePart*) mpart
/*" In addition to the 'original' method bold and italics is no longer broken. The default font is respected also. (improved by Axel) "*/
{
    static NSCharacterSet *etSpecialSet = nil, *newlineSet;
    NSScanner *scanner;
    NSMutableString *output, *rawString;
    NSMutableArray *markerStack;
    OPObjectPair *marker;
    NSString *string, *tag;
    NSMutableArray *attributesToSet;
    NSMutableDictionary *attributeAndRange;
    NSEnumerator *attributesEnumerator;
    int	nofillct, paramct, excerptct, offset, nlSeqLength;
    
    if(etSpecialSet == nil)
    {
        etSpecialSet = [[NSCharacterSet characterSetWithCharactersInString: @"\n\r<"] retain];
        newlineSet = [[NSCharacterSet characterSetWithCharactersInString: @"\n\r"] retain];
    }
    
    if((string = [self _stringFromMessagePart:mpart]) == nil)
        return;
    scanner = [NSScanner scannerWithString:string];
    [scanner setCharactersToBeSkipped: nil];
    markerStack = [NSMutableArray array];
    rawString = [NSMutableString string];
    attributesToSet = [NSMutableArray array];
    nofillct = paramct = excerptct = offset = 0;
    
    // first pass
    while([scanner isAtEnd] == NO)
    {
        NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        
        output = (paramct > 0) ? nil : rawString;
        if([scanner scanUpToCharactersFromSet:etSpecialSet intoString:&string])
        {
            [output appendString:string];
        }
        else if([scanner scanString: @"<" intoString: NULL])
        {
            if([scanner scanString: @"<" intoString: NULL])
            {
                [output appendString: @"<"];
            }
            else
            {
                if([scanner scanUpToString: @">" intoString:&string] == NO)
                    [NSException raise:EDMessageFormatException format: @"Missing `>' in text/enriched body."];
                [scanner scanString: @">" intoString: NULL];
                tag = [string lowercaseString];
                if([tag isEqualToString: @"param"])
                {
                    paramct += 1;
                }
                else if([tag isEqualToString: @"/param"])
                {
                    paramct -= 1;
                }
                else if([tag isEqualToString: @"nofill"])
                {
                    nofillct += 1;
                }
                else if([tag isEqualToString: @"/nofill"])
                {
                    nofillct -= 1;
                }
                else if([tag isEqualToString: @"bold"])
                {
                    marker = [OPObjectPair pairWithObjects:string:[NSNumber numberWithInt:[rawString length]]];
                    [markerStack pushObject:marker];
                }
                else if([tag isEqualToString: @"/bold"])
                {
                    marker = [markerStack popObject];
                    NSAssert([[marker firstObject] isEqualToString: @"bold"], @"unbalanced tags...");
                    attributeAndRange = [NSDictionary dictionaryWithObjectsAndKeys:
                        [marker firstObject], @"tag",
                        [marker secondObject], @"location",
                        [NSNumber numberWithInt:([rawString length] - [[marker secondObject] intValue]) ], @"length",
                        nil, nil];
                    
                    [attributesToSet addObject:attributeAndRange];
                    
                }
                else if([tag isEqualToString: @"italic"])
                {
                    marker = [OPObjectPair pairWithObjects:string:[NSNumber numberWithInt:[rawString length]]];
                    [markerStack pushObject:marker];
                }
                else if([tag isEqualToString: @"/italic"])
                {
                    marker = [markerStack popObject];
                    NSAssert([[marker firstObject] isEqualToString: @"italic"], @"unbalanced tags...");
                    attributeAndRange = [NSDictionary dictionaryWithObjectsAndKeys:
                        [marker firstObject], @"tag",
                        [marker secondObject], @"location",
                        [NSNumber numberWithInt:([rawString length] - [[marker secondObject] intValue]) ], @"length",
                        nil, nil];
                    
                    [attributesToSet addObject:attributeAndRange];
                }
                else if([tag isEqualToString: @"excerpt"])
                {
                    // take care of excerpt/quote marks
                    excerptct += 1;
                    
                    marker = [OPObjectPair pairWithObjects:string:[NSNumber numberWithInt:[rawString length]]];
                    [markerStack pushObject:marker];
                    OPDebugLog(EDTEXTCONTENTCONTROLLER, OPINFO, @"excerpt");
                }
                else if([tag isEqualToString: @"/excerpt"])
                {
                    marker = [markerStack popObject];
                    NSAssert([[marker firstObject] isEqualToString: @"excerpt"], @"unbalanced tags...");
                    attributeAndRange = [NSDictionary dictionaryWithObjectsAndKeys:
                        [marker firstObject], @"tag",
                        [marker secondObject], @"location",
                        [NSNumber numberWithInt:([rawString length] - [[marker secondObject] intValue]) ], @"length",
                        [NSNumber numberWithInt:excerptct], @"excerptDepth",
                        nil, nil];
                    
                    [attributesToSet addObject:attributeAndRange];
                    excerptct -= 1;
                }
                // ##WARNING * a lot of tags are missing
            }
        }
        else if([scanner scanCharactersFromSet:newlineSet intoString:&string])
        {
            if(nofillct > 0)
            {
                [output appendString:string];
            }
            else
            {
                nlSeqLength = [string hasPrefix: @"\r\n"] ? 2 : 1;
                if([string length] == nlSeqLength)
                    [output appendString: @" "];
                else
                    [output appendString:[string substringFromIndex:nlSeqLength]];
            }
        }
        [pool release];
    }
    
    // default font handling included
    text = [[NSMutableAttributedString alloc] initWithString:rawString attributes:[NSDictionary dictionaryWithObject:[GIMessage font] forKey:NSFontAttributeName]];
    
    // second pass
    attributesEnumerator = [attributesToSet objectEnumerator];
    while (attributeAndRange = [attributesEnumerator nextObject])
    {
        int location, length;
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSRange range;
        
        
        tag = [attributeAndRange objectForKey: @"tag"];
        location = [[attributeAndRange objectForKey: @"location"] intValue] + offset;
        length = [[attributeAndRange objectForKey: @"length"] intValue];
        range = NSMakeRange(location, length);
        
        while (NSMaxRange(range) >= [text length])
        {
            range = NSMakeRange(range.location, range.length - 1);
        }
        
        [text fixAttributesInRange:NSMakeRange(0, [text length])];
        
        if ([tag isEqualToString: @"bold"])
        {
            [text applyFontTraits:NSBoldFontMask range:range]; 
        }
        else if ([tag isEqualToString: @"italic"])
        {
            [text applyFontTraits:NSItalicFontMask range:range];
        }
        else if ([tag isEqualToString: @"excerpt"])
        {
            NSNumber *excerptDepth;
            
            excerptDepth = [attributeAndRange objectForKey: @"excerptDepth"];
            
            if (excerptDepth)
            {
                [text addAttribute:OPQuotationAttributeName value:excerptDepth range:range];
            }
        }
        
        [pool release];
    }
}

- (void) _takeTextFromHTMLMessagePart: (EDMessagePart*) mpart
{
	/*
    NSString* charset;
    NSStringEncoding textEncoding;

    if ((charset = [[mpart contentTypeParameters] objectForKey: @"charset"]) == nil) {
        charset = MIMEAsciiStringEncoding;
    }
    
    if((textEncoding = [NSString stringEncodingForMIMEEncoding: charset]) == 0) {
        [NSException raise: EDMessageFormatException format: @"Invalid charset in message part; found '%@'", charset];
    }
	*/
    
    NSData* data = [[self _stringFromMessagePart: mpart] dataUsingEncoding: NSUnicodeStringEncoding];
    text = [[NSMutableAttributedString allocWithZone: [self zone]] initWithHTML:data documentAttributes: NULL];
	
	/*
	NSString* html = [[NSString alloc] initWithData: [mpart contentData] encoding: textEncoding];
	text = [[NSMutableAttributedString alloc] initWithString: [html stringByStrippingHTML]];
	if (NSDebugEnabled) NSLog(@"Converted html to text:\n%@", text);
	[html release];
	 */
}

- (NSAttributedString*) attributedString
{
    NSMutableAttributedString* result;
    
    result = [[[self text] mutableCopy] autorelease]; // mutablecopy needed?
	
	[result urlify];
  
    return result;
}

- (NSString*) string
{	
	NSString* type = [part contentType];
	
	// Prevent HTML rendering - strip HTML instead!
	if ([type isEqualToString: @"text/html"]) {
		
		NSString* html = [self _stringFromMessagePart: part];
		NSString* result = [html stringByStrippingHTML];
		if (NSDebugEnabled) NSLog(@"Converted html to the following text:\n%@", result);
		return result;
	}	
    return [[self text] string];
}

//---------------------------------------------------------------------------------------
    @end
//---------------------------------------------------------------------------------------
