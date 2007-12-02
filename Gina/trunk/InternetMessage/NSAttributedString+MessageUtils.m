/* 
     $Id: NSAttributedString+MessageUtils.m,v 1.10 2005/01/26 09:44:51 mikesch Exp $

     Copyright (c) 2001 by Axel Katerbau. All rights reserved.

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

#import <AppKit/AppKit.h>
#import <Foundation/NSDebug.h>
#import "NSAttributedString+MessageUtils.h"
#import "NSString+MessageUtils.h"
#import "NSString+Extensions.h"
#import "NSAttributedString+Extensions.h"
#import "EDContentCoder.h"
#import "NSFileWrapper+OPAppleFileExtensions.h"
#import "OPInternetMessageAttachmentCell.h"
#import "NSArray+Extensions.h"

#define QuotationLevel0Color      @"QuotationLevel0Color"
#define QuotationLevel1Color      @"QuotationLevel1Color"
#define QuotationLevel2Color      @"QuotationLevel2Color"
#define QuotationLevel3Color      @"QuotationLevel3Color"
#define QuotationLevel4Color      @"QuotationLevel4Color"
#define QuotationColorCyclicFlag  @"QuotationColorCyclicFlag"


// Functions for converting between NSString and NSColor.
// The intended purpose of this category is storing and retrieving NSColor objects from the defaults.

NSString* OPStringFromColor(NSColor* color)
/*"Returns a string with the %{color}'s RGB and alpha values encoded."*/
{
    float red, green, blue, alpha;
    [color getRed:&red green:&green blue:&blue alpha:&alpha];    
    return [NSString stringWithFormat: @"%f %f %f %f", red, green, blue, alpha];
}


NSColor* OPColorFromString(NSString* string)
/*" Returns a NSColor object with the RGB and alpha values encoded in the string (in the same format as created by #{OPStringFromColor()}). "*/
{
	if (![string length]) 
		return nil;
	
    NSArray* rgba = [string componentsSeparatedByString: @" "];
    
    if ([rgba count] != 4) {
        NSLog(@"OPColorFromString(): Illegal number of components in string for NSColor (%@)", string);
        return nil;
    }
    
    NSColor *color = [NSColor colorWithCalibratedRed:[[rgba objectAtIndex:0] floatValue]
                                               green:[[rgba objectAtIndex:1] floatValue]
                                                blue:[[rgba objectAtIndex:2] floatValue]
                                               alpha:[[rgba objectAtIndex:3] floatValue]];
    
    return color;
}



@implementation NSAttributedString (QuotationExtensions)

/*" Returns a dark blue, 0.1 0.1 0.5 (calibrated). "*/

+ (NSColor *)defaultLinkColor
{
    return [NSColor colorWithCalibratedRed:0.1 green:0.1 blue:0.5 alpha:1.0];
}


- (NSString*) quotedStringWithLineLength:(int)lineLength byIncreasingQuoteLevelBy:(int)levelDelta
{
    NSMutableAttributedString *workString;
    NSMutableString *result;
    
    workString = [self mutableCopy];
    result = [NSMutableString stringWithCapacity:[self length]];
    
    // remove prefixes
    {
        unsigned int length;
        NSRange effectiveRange;
        id attributeValue;
        
        length = [workString length];
        effectiveRange = NSMakeRange(0, 0);
        
        while (NSMaxRange(effectiveRange) < length) 
        {
            NSAutoreleasePool *pool;
            
            pool = [[NSAutoreleasePool alloc] init];
            
            attributeValue = [workString attribute:OPQuotationPrefixAttributeName
                                           atIndex:NSMaxRange(effectiveRange) effectiveRange:&effectiveRange];
            
            if (attributeValue != nil)
            {
                [workString deleteCharactersInRange:effectiveRange];
                
                // reset values because of reduction/shortening of the work string
                length = [workString length];
                effectiveRange = NSMakeRange(0, 0);
            }
            
            [pool release];
        }
    }
    
    // split on quotation level
    {
        NSRange limitRange;
        NSRange effectiveRange;
        id attributeValue;
        
        limitRange = NSMakeRange(0, [workString length]);
        
        while (limitRange.length > 0) 
        {
            NSAutoreleasePool *pool;
            NSString *partialString;
            NSMutableString *quotePrefix;
            int totalQuoteDepth, i;
            
            totalQuoteDepth = levelDelta;
            
            pool = [[NSAutoreleasePool alloc] init];
            
            attributeValue = [workString attribute:OPQuotationAttributeName
                                           atIndex:limitRange.location longestEffectiveRange:&effectiveRange
                                           inRange:limitRange];
            
            partialString = [[workString string] substringWithRange:effectiveRange];
            
            if (attributeValue != nil) // is quote
            {
                // adjust quote depth by adding given quote depth
                totalQuoteDepth += [(NSNumber*) attributeValue intValue];
            }
            
            if (totalQuoteDepth > 0)
            {
                BOOL endsWithLineBreak;
                NSString* lineBreakSeq;
                
                lineBreakSeq = @"\r\n";
                if([partialString rangeOfString:lineBreakSeq].length == 0)
                    lineBreakSeq = @"\n";
                
                endsWithLineBreak = [partialString hasSuffix:lineBreakSeq];
                
                // building quote prefix
                quotePrefix = [NSMutableString stringWithCapacity:totalQuoteDepth+1];
                
                for (i = 0; i < totalQuoteDepth; i++)
                {
                    [quotePrefix appendString: @">"];
                }
                
                [quotePrefix appendString: @" "];
                
                // wrap to lineLength characters
                partialString = [partialString stringByWrappingToLineLength:[quotePrefix length] < lineLength ? lineLength - [quotePrefix length] : lineLength];
                
                partialString = [partialString substringToIndex:[partialString length] - [lineBreakSeq length]];
                if ([partialString hasSuffix:lineBreakSeq]) // chop line break
                {
                    // Error in ED's framework because it adds a line break add the end regardless...
                    partialString = [partialString substringToIndex:[partialString length] - [lineBreakSeq length]];
                }
                
//                partialString = [partialString stringByStrippingTrailingWhitespacesAndNewlines];
                
                // apply quote prefix
                partialString = [partialString stringByPrefixingLinesWithString:quotePrefix];
            }
            
            [result appendString:partialString];
            
            limitRange = NSMakeRange(NSMaxRange(effectiveRange),
                                     NSMaxRange(limitRange) - NSMaxRange(effectiveRange));
            
            [pool release];
        }
    }
    
    [workString release];
    
    return result;
}

- (NSString *)firstLevelMicrosoftTOFUQuote
{
	NSString *result = nil;
	NSString *plainText = [self string];
	
	NSRange range = [plainText rangeOfString:@"-----"];
	
	if (range.location != NSNotFound
		&& ![self attribute:OPQuotationAttributeName 
				   atIndex:range.location 
			effectiveRange:NULL]) // found TOFU
	{
		range = [plainText lineRangeForRange:range];
		unsigned int quoteStart = range.location + range.length;
		NSRange stopRange;
		
		if (quoteStart < [plainText length]) // still in bounds?
		{
			// test, if a stopper is present:
			unsigned int stopPosition = NSNotFound;
			unsigned int searchPosition = quoteStart;
			do
			{
				stopRange = [plainText rangeOfString:@"--" options:0 range:NSMakeRange(searchPosition, [plainText length] - searchPosition)];
				
				if (stopRange.location != NSNotFound)
				{
					range = [plainText lineRangeForRange:stopRange];
					if (range.location == stopRange.location)
					{
						stopPosition = range.location;
					}
				}
			}
			while (stopRange.location != NSNotFound && stopPosition == NSNotFound);
			
			if (stopPosition == NSNotFound)
			{
				result = [plainText substringFromIndex:quoteStart];
			}
			else
			{
				result = [plainText substringWithRange:NSMakeRange(quoteStart, stopPosition - quoteStart)];
			}
			
			range = [result paragraphRangeForRange:NSMakeRange(0, 0)];
			
			while (range.location != NSNotFound && range.length > 6)
			{
				range = [result paragraphRangeForRange:NSMakeRange(range.location + range.length, 0)];
			}
			
			if (range.location != NSNotFound)
			{
				result = [result substringFromIndex:range.location + range.length];
			}

		}
	}
	
	return result;
}

@end

@implementation NSMutableAttributedString (QuotationExtensions)

- (NSParagraphStyle *)_paragraphStyleForQuotationPrefix: (NSAttributedString*) quotationPrefix firstParagraph:(BOOL)firstParagraph
{
    NSMutableParagraphStyle *result;
    
    result = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [result setParagraphStyle:[NSParagraphStyle defaultParagraphStyle]];
    
    [result setHeadIndent:[quotationPrefix size].width];
    if (! firstParagraph)
    {
        [result setFirstLineHeadIndent:[quotationPrefix size].width];
    }
    
    return result;
}

- (NSAttributedString *)_prefixForQuotationLevel:(int)quotationLevel
{
    NSMutableAttributedString *result;
    int i;
    
    result = [[[NSMutableAttributedString alloc] init] autorelease];
    for (i = 0; i < quotationLevel; i++)
    {
        [result appendString: @">"];
    }
    
    if (quotationLevel > 0)
        [result appendString: @" "];
    
    return result;
}

- (NSColor *)_colorForQuotationLevel:(int)quotationLevel
{
    if (quotationLevel <= 0)
        return nil;
        
    NSColor *color = nil;
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    if ([userDefaults boolForKey:QuotationColorCyclicFlag])
        quotationLevel %= 5;
        
    switch (quotationLevel)
    {
        case 1:  color = OPColorFromString([userDefaults objectForKey:QuotationLevel1Color]);
                 break;
        case 2:  color = OPColorFromString([userDefaults objectForKey:QuotationLevel2Color]);
                 break;
        case 3:  color = OPColorFromString([userDefaults objectForKey:QuotationLevel3Color]);
                 break;
        case 4:  color = OPColorFromString([userDefaults objectForKey:QuotationLevel4Color]);
                 break;
        default: color = OPColorFromString([userDefaults objectForKey:QuotationLevel0Color]);
    }
    
    if (color == nil)
        switch (quotationLevel)
        {
			// todo: remove the following code and replace it with registered user default values!
            case 1:  color = [NSColor colorWithCalibratedRed:0.40 green:0.40 blue:0.40 alpha:1.0];
                     break;
            case 2:  color = [NSColor colorWithCalibratedRed:0.55 green:0.55 blue:0.55 alpha:1.0];
                     break;
            case 3:  color = [NSColor colorWithCalibratedRed:0.65 green:0.65 blue:0.65 alpha:1.0];
                     break;
            case 4:  color = [NSColor colorWithCalibratedRed:0.75 green:0.75 blue:0.75 alpha:1.0];
                     break;
            default: color = [NSColor colorWithCalibratedRed:0.85 green:0.85 blue:0.85 alpha:1.0];
        }
        
    return color;
}

- (void)prepareQuotationsForDisplay
/*"Adds paragraph style attributes to quoted ranges."*/
{
    NSRange limitRange;
    NSRange effectiveRange;
    id attributeValue;

    limitRange = NSMakeRange(0, [self length]);

    while (limitRange.length > 0) 
    {
        attributeValue = [self attribute:OPQuotationAttributeName
            atIndex:limitRange.location longestEffectiveRange:&effectiveRange
            inRange:limitRange];
        
        if (attributeValue == nil) // attribute does not exist at index
        {
            if (&effectiveRange == NULL) // not found
            {
                limitRange.length = 0; // set to end
            }
        }
        else // attribute exists in effectiveRange
        {
            NSAttributedString *quotationPrefix;
            NSRange firstParEnd, firstParRange;
            int quotationLevel;
            
            quotationLevel = [(NSNumber*) attributeValue intValue];
            
            // first paragraph
            quotationPrefix = [self _prefixForQuotationLevel:quotationLevel];

            [self insertAttributedString:quotationPrefix atIndex:effectiveRange.location];
            [self addAttribute:OPQuotationPrefixAttributeName value: @"QuotationPrefix" range:NSMakeRange(effectiveRange.location, [quotationPrefix length])];
    
            effectiveRange.length += [quotationPrefix length];
            limitRange.length     += [quotationPrefix length];
            
            firstParEnd = [[[self attributedSubstringFromRange:effectiveRange] string] rangeOfString: @"\n"];
            
            if (firstParEnd.location == NSNotFound)
                firstParRange = effectiveRange;
            else
                firstParRange = NSMakeRange(effectiveRange.location, NSMaxRange(firstParEnd));
                
            [self applyFontTraits:NSItalicFontMask range:firstParRange];
            [self addAttribute:NSForegroundColorAttributeName value:[self _colorForQuotationLevel:quotationLevel] range:firstParRange];
            [self addAttribute:NSParagraphStyleAttributeName value:[self _paragraphStyleForQuotationPrefix:quotationPrefix firstParagraph: YES] range:firstParRange];
            
            // remaining paragraphs
            if (NSMaxRange(firstParRange) < NSMaxRange(effectiveRange))
            {
                NSRange remainingParRange;
                remainingParRange = NSMakeRange(NSMaxRange(firstParRange), NSMaxRange(effectiveRange) - NSMaxRange(firstParRange));
                
                [self applyFontTraits:NSItalicFontMask range:remainingParRange];
                [self addAttribute:NSForegroundColorAttributeName value:[self _colorForQuotationLevel:quotationLevel] range:remainingParRange];
                [self addAttribute:NSParagraphStyleAttributeName value:[self _paragraphStyleForQuotationPrefix:quotationPrefix firstParagraph: NO] range:remainingParRange];
            }
        }
                
        limitRange = NSMakeRange(NSMaxRange(effectiveRange),
            NSMaxRange(limitRange) - NSMaxRange(effectiveRange));
    }
}

@end

@interface NSMutableAttributedStringQuotationTest : NSObject 
{
}
@end

@implementation NSMutableAttributedStringQuotationTest

- (void) testPrepare
{
    /*
    NSString *originalString;
    NSMutableAttributedString *prepared; //, *expected;
        
    originalString = @"> a really really really long long long long line with mooooore than seventynine characters to make the wrapping process neccessary, doh.\n> ..\nThis is a test\n a blank\n  two blanks\n";
    
    prepared = [[[originalString attributedStringWithQuotationAttributes] mutableCopy] autorelease];
            
    [prepared prepareQuotationsForDisplay];
    */    
//    MPWAssertIsEqual(originalString, decodedString);
}

+ (id) testFixture
{
    return [[[self alloc] init] autorelease];
}

+ (id) testSelectors
{
    return [NSArray arrayWithObjects: @"testPrepare", nil];
}

- (void) testTeardown
{
}

- (void) testSetup
{
}

@end

@interface NSAttributedStringQuotationTest : NSObject 
{
}
@end

@implementation NSAttributedStringQuotationTest

- (void) testQuoteGedoens
{
    NSMutableAttributedString *testAttributedString;
    NSString *testString, *quotedbreakString;
    
    testAttributedString = [[[@"Long Long Long Long Long Long Long Long Long Long Long Long Long Long Long Long Long Long Long Long Long Long Long Long Long Long Long Long Long Long Long Long Long Long Long Long Long Long Long Long Long Long Long Long" attributedStringWithQuotationAttributes] mutableCopy] autorelease];
    
    [testAttributedString prepareQuotationsForDisplay];
    testString = [testAttributedString string];
    quotedbreakString = [testAttributedString quotedStringWithLineLength:72 byIncreasingQuoteLevelBy:0];
    
    NSAssert([testString isEqual: quotedbreakString], @"Equal test failed");
}

+ (id) testFixture
{
    return [[[self alloc] init] autorelease];
}

+ (id) testSelectors
{
    return [NSArray arrayWithObjects: @"testQuoteGedoens", nil];
}

- (void) testTeardown
{
}

- (void) testSetup
{
}

@end

@implementation NSMutableAttributedString (MessageAdditions)

/*" Appends the string %aURL as a clickable, underlined URL in the default link color. "*/

- (void) appendURL: (NSString*) aURL
{
    [self appendURL:aURL linkColor:[[self class] defaultLinkColor]];
}


/*" Appends the string %aURL as a clickable, underlined URL in the link color specified. "*/

- (void) appendURL: (NSString*) aURL linkColor: (NSColor*) linkColor
{
    NSRange	urlRange;
    
    urlRange.location = [self length];
    [self appendString:aURL];
    urlRange.length = [self length] - urlRange.location;
    [self addAttribute:NSLinkAttributeName value:aURL range:urlRange];
    [self addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithInt:NSSingleUnderlineStyle] range:urlRange];
    if(linkColor != nil)
        [self addAttribute:NSForegroundColorAttributeName value:linkColor range:urlRange];
}


/*" Appends the image represented by %data with the filename %name to the string. The image is displayed inline if possible. "*/

- (void) appendImage: (NSData*) data name: (NSString*) name
{
    NSFileWrapper	 	*wrapper;
    NSTextAttachment 	*attachment;
    NSAttributedString	*attchString;
    
    wrapper = [[[NSFileWrapper alloc] initRegularFileWithContents:data] autorelease];
    if(name != nil)
        [wrapper setPreferredFilename: name];
    // standard text attachment displays everything possible inline
    attachment = [[[NSTextAttachment alloc] initWithFileWrapper:wrapper] autorelease];
    attchString = [NSAttributedString attributedStringWithAttachment:attachment];
    [self appendAttributedString:attchString];
}

/*" Appends the attachments represented by %data with the filename %name to the string. "*/
- (void) appendAttachment: (NSData*) data name: (NSString*) name
{
    NSFileWrapper		*wrapper;
    NSTextAttachment 	*attachment;
    NSCell			 	*cell;
    NSAttributedString	*attchString;
    
    wrapper = [[[NSFileWrapper alloc] initRegularFileWithContents:data] autorelease];
    if(name != nil)
        [wrapper setPreferredFilename: name];
    attachment = [[[NSTextAttachment alloc] initWithFileWrapper:wrapper] autorelease];
    cell = (NSCell *)[attachment attachmentCell];
    NSAssert([cell isKindOfClass:[NSCell class]], @"AttachmentCell must inherit from NSCell.");
    [cell setImage:[[NSWorkspace sharedWorkspace] iconForFileType:[name pathExtension]]];
    attchString = [NSAttributedString attributedStringWithAttachment:attachment];
    [self appendAttributedString:attchString];
}


//#warning axel->axel: should be obsolete
/*
- (void) appendAttachment: (NSData*) data name: (NSString*) name description: (NSString*) description
{
    NSFileWrapper*      wrapper;
    NSTextAttachment*   attachment;
    id                  cell;
    NSImage*            image;
    NSAttributedString*	attchString;

    wrapper = [[[NSFileWrapper alloc] initRegularFileWithContents:data] autorelease];
    if(name != nil)
        [wrapper setPreferredFilename: name];
    attachment = [[[NSTextAttachment alloc] initWithFileWrapper:wrapper] autorelease];
    cell = [attachment attachmentCell];
    NSAssert([cell isKindOfClass:[NSCell class]], @"AttachmentCell must inherit from NSCell.");
    image = [[NSWorkspace sharedWorkspace] iconForFileType:[name pathExtension]];
    if(image == nil) {
      // use default image
      image = [[NSWorkspace sharedWorkspace] iconForFileType: @"txt"];
    }
    [cell setImage:image];
    attchString = [NSAttributedString attributedStringWithAttachment:attachment];
    [self appendAttributedString:attchString];
    [self appendAttributedString:[[[NSAttributedString alloc] initWithString:[NSString stringWithFormat: @"[%@]\n", description]] autorelease]];
}
*/

- (void) appendAttachmentWithFileWrapper: (NSFileWrapper*) aFileWrapper
    /*" The file wrapper is materialized in a temp location
    (it is taken care of a possibly existing resource fork). The attachment is then appended to the receiver.
    The filewrapper's contents are shown inline if possible and EDContentCoder says so.
    (e.g. mp3 file shows player, images are shown rather than an icon). "*/
{
    [self appendAttachmentWithFileWrapper: aFileWrapper 
                     showInlineIfPossible: YES];
}


- (void)appendAttachmentWithFileWrapper:(NSFileWrapper *)aFileWrapper 
                   showInlineIfPossible:(BOOL)shouldShowInline
/*" The file wrapper is materialized in a temp location
    (it is taken care of a possibly existing resource fork). The attachment is then appended to the receiver.
    If shouldShowInline is YES the filewrapper's contents are shown inline if possible
    (e.g. mp3 file shows player, images are shown rather than an icon). "*/
{
    NSTextAttachment *attachment;
    NSAttributedString *attchString;
    NSString *directoryname;
    NSString *path;
    OPInternetMessageAttachmentCell *cell = nil;
    
    // write file wrapper's forks to disk
    do 
    {
        directoryname = [NSString temporaryFilename];
    }
    while (! [[NSFileManager defaultManager] createDirectoryAtPath:directoryname attributes:nil]);
    
    path = [directoryname stringByAppendingPathComponent:[aFileWrapper preferredFilename]];
    
    if (! [aFileWrapper writeForksToFile:path atomically:YES updateFilenames:YES])
    {
        [NSException raise:NSGenericException format:@"Error writing attachment to temporary directory"];
    }
    
    path = [directoryname stringByAppendingPathComponent:[aFileWrapper filename]];
        
    // set icon
/*    if (shouldShowInline)
    {
        [aFileWrapper setIcon:[[NSWorkspace sharedWorkspace] iconForFile:path]];
    }
    else 
    {
        [aFileWrapper setIcon:[NSImage imageNamed: @"NSApplicationIcon"]];
    }
    */
    
    // add attachment to attributed string
    attachment = [[[NSTextAttachment alloc] initWithFileWrapper:aFileWrapper] autorelease];

    //if (! shouldShowInline)
    {
        cell = [[[OPInternetMessageAttachmentCell alloc] initImageCell:[[NSWorkspace sharedWorkspace] iconForFile:path]] autorelease];
		[cell setAttachment:attachment];
        [attachment setAttachmentCell:cell];
		
		NSMenu* menu = [[[NSMenu alloc] initWithTitle: @"Context"] autorelease];
		[menu insertItemWithTitle: @"Save..." action: @selector(saveAttachment:) keyEquivalent: @"" atIndex: 0];
		[cell setMenu: menu];
		
    }
    
    attchString = [NSAttributedString attributedStringWithAttachment:attachment];
    
    [self appendAttributedString:attchString];
    [self addAttribute:OPAttachmentPathAttribute value:path range:NSMakeRange([self length] - 1, 1)];
}

//---------------------------------------------------------------------------------------
//	URLIFIER
//---------------------------------------------------------------------------------------

- (NSMutableAttributedString *)urlify
{
    return [self urlifyWithLinkColor:[[self class] defaultLinkColor] range:NSMakeRange(0, [self length])];
}


- (NSMutableAttributedString *)urlifyWithLinkColor: (NSColor*) linkColor
{
    return [self urlifyWithLinkColor:linkColor range:NSMakeRange(0, [self length])];
}


- (NSMutableAttributedString *)urlifyWithLinkColor: (NSColor*) linkColor range:(NSRange)range
{
    static NSCharacterSet *colon = nil, *alpha, *urlstop, *ulfurlstop;
    static NSString   	  *scheme[] = { @"http", @"https", @"ftp", @"mailto", @"gopher", @"news", nil };
    static unsigned int   maxServLength = 6;
    NSString			  *string;
    NSMutableString *url;
    NSRange				  r, remainingRange, possSchemeRange, schemeRange, urlRange, badCharRange;
    unsigned int		  nextLocation, endLocation, i;
    // ulfs stuff
    BOOL schemeRangeIsAtBeginning = NO;
    BOOL urlIsWrappedByBrackets = NO;
    
    if(colon == nil)
    {
        colon = [[NSCharacterSet characterSetWithCharactersInString: @":"] retain];
        alpha = [[NSCharacterSet alphanumericCharacterSet] retain];
        //urlstop = [[NSCharacterSet characterSetWithCharactersInString: @"\"<>()[]',; \t\n\r"] retain];
        urlstop = [[NSCharacterSet characterSetWithCharactersInString: @"\"<>()[]' \t\n\r"] retain];
        // if the url is wrapped by brackets we will use this one:
        ulfurlstop = [[NSCharacterSet characterSetWithCharactersInString: @">"] retain];
        // problem is that if there is no closing '>' everything until the end of string will be treated as url
    }
    
    string = [self string];
    nextLocation = range.location;
    endLocation = NSMaxRange(range);
    while(1)
    {
        remainingRange = NSMakeRange(nextLocation, endLocation - nextLocation);
        r = [string rangeOfCharacterFromSet:colon options:0 range:remainingRange];
        if(r.length == 0)
            break;
        nextLocation = NSMaxRange(r);
        
        if(r.location < maxServLength) 
        {
            possSchemeRange = NSMakeRange(0,  r.location);
            schemeRangeIsAtBeginning = YES;
        }    
        else
        {
            possSchemeRange = NSMakeRange(r.location - 6,  6);
            schemeRangeIsAtBeginning = NO;
        }
        // no need to clean up composed chars becasue they are not allowed in URLs anyway
        for(i = 0; scheme[i] != nil; i++)
        {
            schemeRange = [string rangeOfString:scheme[i] options:(NSBackwardsSearch|NSAnchoredSearch|NSLiteralSearch) range:possSchemeRange];
            if(schemeRange.length != 0)
            {
                // if the char before schemeRange is a '<' we need to look for it as the end of the string
                if ((schemeRange.location > 0) && ([string characterAtIndex:(schemeRange.location - 1)] == '<'))
                    urlIsWrappedByBrackets = YES;
                else
                    urlIsWrappedByBrackets = NO;
                
                r.length = endLocation - r.location;
                
                // check to determine the correct urlstop CharacterSet
                if (urlIsWrappedByBrackets)
                    r = [string rangeOfCharacterFromSet:ulfurlstop options:0 range:r];
                else
                    r = [string rangeOfCharacterFromSet:urlstop options:0 range:r];
                
                if(r.length == 0) // not found, assume URL extends to end of string
                    r.location = [string length];
                urlRange = NSMakeRange(schemeRange.location, r.location - schemeRange.location);
                if([string characterAtIndex:NSMaxRange(urlRange) - 1] == (unichar)'.')
                    urlRange.length -= 1;
                url = [NSMutableString stringWithString:[string substringWithRange:urlRange]];
                
                // remove bad characters (like CR LF) from url
                badCharRange = [url rangeOfCharacterFromSet:urlstop options:0 range:NSMakeRange(0, [url length])];
                while (badCharRange.location != NSNotFound)
                {
                    [url deleteCharactersInRange:badCharRange];
                    badCharRange = [url rangeOfCharacterFromSet:urlstop options:0 range:NSMakeRange(0, [url length])];
                }
                
                [self addAttribute:NSLinkAttributeName value:url range:urlRange];
                [self addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithInt:NSSingleUnderlineStyle] range:urlRange];
                if(linkColor != nil)
                    [self addAttribute:NSForegroundColorAttributeName value:linkColor range:urlRange];
                nextLocation = urlRange.location + urlRange.length;
                break;
            }
        }
    }
    
    return self;
}

- (NSArray *)divideContentStringTypedStrings 
{
    unsigned int length, i, startLocation;
    NSMutableArray *partContentStrings;
    
    // find all attachments
    if (! [self containsAttachments]) 
    {
        if (NSDebugEnabled) NSLog(@"does not contain an attachment");
        return [NSArray arrayWithObject:[NSArray arrayWithObjects:[NSNull null], self, nil]];
    }
    
    if (NSDebugEnabled) NSLog(@"contains an attachment!");
    length = [self length];
    partContentStrings = [NSMutableArray array];
    startLocation = 0;
    
    for (i = 0; i < length; i++) 
    {
        NSRange range;
        NSMutableAttributedString *string;
        OPObjectPair *typeAndContent;
        unsigned int partContentStringsCount;
        id attribute;
        
        attribute = [self attribute:NSAttachmentAttributeName
                            atIndex:i
                     effectiveRange:&range];
        
        i = range.location + range.length - 1;
        
        string = [[NSMutableAttributedString alloc] initWithAttributedString:[self attributedSubstringFromRange:range]];
        
        partContentStringsCount = [partContentStrings count];
        
        if (partContentStringsCount == 0) 
        {
            typeAndContent = [NSArray arrayWithObjects:attribute, string, nil];
            [partContentStrings addObject:typeAndContent];
        } 
        else 
        {
            if(attribute) 
            {
                typeAndContent = [NSArray arrayWithObjects:attribute, string, nil];
                [partContentStrings addObject:typeAndContent];
            } 
            else 
            {
                NSMutableAttributedString* lastString;
                lastString = [[partContentStrings objectAtIndex:partContentStringsCount - 1] objectAtIndex:1];
                
                if ([lastString containsAttachments]) 
                {
                    typeAndContent = [NSArray arrayWithObjects:attribute, string, nil];
                    [partContentStrings addObject:typeAndContent];
                } 
                else {
                    [lastString appendAttributedString:string];
                }
            }
        }    
        [string release];
    }
    
    return partContentStrings;
}

- (BOOL)hasRichAttributes {
  // hack! this method has to be implemented to allow support of rich text!
    return NO;
}

- (NSArray*) singleAttributeStrings {
    unsigned int length;
    unsigned int i, startLocation;
    NSMutableArray *singleAttributeStrings;
    
    length = [self length];
    singleAttributeStrings = [NSMutableArray array];
    startLocation = 0;
    
    for(i=0; i<length; i++) {
        NSRange range;
        
        [self attributesAtIndex:i
          longestEffectiveRange:&range
                        inRange:NSMakeRange(i, length - i)];
        
        i = range.location + range.length - 1;
        
        NSLog(@"snippet: %@", [[self attributedSubstringFromRange:range] string]);
        [singleAttributeStrings addObject:[self attributedSubstringFromRange:range]];
    }
    
    return singleAttributeStrings;
}

- (NSString*) encodeTextEnriched 
{
    NSMutableString *text;
    NSArray         *singleAttributeStrings;
    unsigned int    count, i;
    NSMutableArray* tagStack = [NSMutableArray array];
    
    singleAttributeStrings = [self singleAttributeStrings];
    text = [NSMutableString string];
    
    count = [singleAttributeStrings count];
    
    NSLog(@"count: %u", count);
    
    for (i=0; i<count; i++) {
        NSAttributedString *attributedString;
        NSDictionary *attributes;
        NSString *value;
        
        attributedString = [singleAttributeStrings objectAtIndex:i];
        attributes = [attributedString attributesAtIndex:0 effectiveRange: NULL];
        
        NSLog(@"Attributes: <%@>", [attributes description]);
    //underline
        if([attributes objectForKey:NSUnderlineStyleAttributeName] != nil) {
            [text appendString: @"<underline>"];
            [tagStack pushObject: @"</underline>"];
        }
        
    //font
        if((value = [attributes objectForKey:NSFontAttributeName]) != nil) {
            NSFont *font = (NSFont *)value;
            NSFontTraitMask traitMask = [[NSFontManager sharedFontManager] traitsOfFont:font];
            
      // bold
            if(traitMask & NSBoldFontMask) {
                [text appendString: @"<bold>"];
                [tagStack pushObject: @"</bold>"];
            }
            
      // italic
            if(traitMask & NSItalicFontMask) {
                [text appendString: @"<italic>"];
                [tagStack pushObject: @"</italic>"];
            }
        }
        
        [text appendString:[attributedString string]];
        
        while([tagStack count] > 0) {
            NSString *closingTag;
            closingTag = [tagStack popObject];
            [text appendString:closingTag];
        }
    }
    return text;
}


@end

