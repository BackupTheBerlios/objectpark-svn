/*
 $Id: GIMessage+Rendering.m,v 1.5 2005/03/07 22:45:51 theisen Exp $
 
 Copyright (c) 2002 by Axel Katerbau. All rights reserved.
 Parts Copyright (c) 2004 by Dirk Theisen. All rights reserved.
 
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

#import "GIMessage+Rendering.h"
//#import "GIPeopleImageCache.h"
#import "GIUserDefaultsKeys.h"
#import "NSAttributedString+Extensions.h"
#import "OPInternetMessage.h"
#import "OPInternetMessage+GinkoExtensions.h"
#import "NSString+MessageUtils.h"
#import "NSAttributedString+MessageUtils.h"
#import "EDMessagePart+OPExtensions.h"

#define DEFAULTCACHECAPACITY ((unsigned int)10)

static inline NSString *nilGuard(NSString *str)
{
    return str ? str : @"";
}

@implementation GIMessage (Rendering)
/*" Renders a message as an attributed string. This includes header lines as defined in the preferences (plus the default ones). */



/*" Returns an array of all the header names that Ginko is set up to display (if existent). "*/
+ (NSArray *)headersShown
{
	static NSArray *headersShown = nil;
	
    if (!headersShown) 
    {
        headersShown = [[NSArray alloc] initWithObjects:
						  @"Resent-From",
						  @"Resent-To",
						  @"From",
						  @"Newsgroups",
						  @"Subject",
						  @"To",
						  @"Cc",
						  @"Bcc",
						  @"Reply-To",
						  @"Date",
						  nil];
    }
    return headersShown;
}

static NSString *templatePrefix = nil;
static NSString *templateRow = nil;
static NSString *templatePostfix = nil;

+ (void) initTemplate
{    
    if (!templatePrefix)
    {
        NSError *error = nil;
        NSString *template = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource: @"HeaderTemplate" ofType: @"html"] encoding: NSUTF8StringEncoding error:&error];
        
        NSAssert(template != nil, @"header template could not be loaded");

        NSRange range = [template rangeOfString: @"<tr>"];
        NSAssert(range.location != NSNotFound, @"table start not found");
        templatePrefix = [[template substringWithRange:NSMakeRange(0, range.location)] retain];
        NSAssert(templatePrefix != nil, @"header prefix could not be computed");   
        
        NSRange rowRange = [template rangeOfString: @"</tr>"];
        NSAssert(rowRange.location != NSNotFound, @"table row not found");        
        
        int position = rowRange.location + rowRange.length;
        templateRow = [[template substringWithRange:NSMakeRange(range.location, position - (range.location))] retain];

        templatePostfix = [[template substringWithRange:NSMakeRange(position, [template length] - (position))] retain];        
    }
}


- (NSMutableAttributedString *) tableCellAttributedStringWithString:(NSString *)string
															  table:(NSTextTable *)table
													backgroundColor:(NSColor *)backgroundColor
														borderColor:(NSColor *)borderColor
																row:(int)row
															 column:(int)column
{
    NSTextTableBlock *block = [[NSTextTableBlock alloc]
        initWithTable:table 
		  startingRow:row 
			  rowSpan:1 
	   startingColumn:column 
		   columnSpan:1];
    [block setBackgroundColor:backgroundColor];
    [block setBorderColor:borderColor];
    [block setWidth:4.0 type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockBorder];
    [block setWidth:6.0 type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockPadding];
	
    NSMutableParagraphStyle *paragraphStyle = 
        [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [paragraphStyle setTextBlocks:[NSArray arrayWithObjects:block, nil]];
    [block release];
	
    NSMutableAttributedString *cellString = 
        [[NSMutableAttributedString alloc] initWithString: nilGuard(string)];
    [cellString addAttribute:NSParagraphStyleAttributeName 
					   value:paragraphStyle 
					   range:NSMakeRange(0, [cellString length])];
    [paragraphStyle release];
	
    return [cellString autorelease];
}

	
+ (NSMutableAttributedString*) fieldTableWithRowCount: (int) rowCount
{
    NSParameterAssert(rowCount > 0);
    
    [self initTemplate];
    
    NSMutableString* string = [NSMutableString stringWithString:templatePrefix];
    int i;
    
    for (i = 0; i < rowCount; i++) [string appendString: templateRow];
    
    [string appendString:templatePostfix];
    
    NSMutableAttributedString* result = [[[NSMutableAttributedString alloc] initWithHTML: [string dataUsingEncoding: NSUTF8StringEncoding] documentAttributes: NULL] autorelease];
	
	
	return result;
}


+ (void)_appendFieldName:(NSString *)fieldName andDecodedHeader:(NSString *)decodedHeader  toAttributedString:(NSMutableAttributedString *)displayString
{
	
    /*
    NSMutableAttributedString *template = [self headerTemplate];
    NSRange nameRange = [[template string] rangeOfString: @"$fieldname$"];
    
    NSAssert(nameRange.location != NSNotFound, @"name range not found");
    
    [template replaceCharactersInRange:nameRange withString:NSLocalizedString(fieldName, @"A field name in the message header like 'Subject'")];
    
    NSRange valueRange = [[template string] rangeOfString: @"$fieldvalue$"];
    NSAssert(valueRange.location != NSNotFound, @"value range not found");
    [template replaceCharactersInRange:valueRange withString:decodedHeader];
    
    [displayString appendAttributedString:template];
    //[displayString appendString: @"\n"];
    
*/
    int startLocation, endLocation;
    
    startLocation = [displayString length];
    [displayString appendString: NSLocalizedString(fieldName, @"A field name in the message header like 'Subject'")];
    [displayString appendString:@": "];
    
    endLocation = [displayString length] - 1;
    
    // ATTENTION setting the message font here
    [displayString addAttribute:NSFontAttributeName value:[self font] range:NSMakeRange(startLocation, [displayString length] - startLocation)];
    
    [displayString applyFontTraits:NSBoldFontMask range:NSMakeRange(startLocation, endLocation - startLocation)];
    
    startLocation = [displayString length];
    
    [displayString appendString:decodedHeader];
    [displayString appendString:@"\n"];
    
    endLocation = [displayString length] - 1;
    
    [displayString applyFontTraits:NSUnboldFontMask range:NSMakeRange(startLocation, endLocation - startLocation)];
}

/*" Returns empty string if aMessage is nil. "*/
+ (NSMutableAttributedString *)renderedHeaders:(NSArray *)headers forMessage:(OPInternetMessage *)aMessage showOthers:(BOOL)showOthers
{
    NSMutableAttributedString *displayString = [[[NSMutableAttributedString alloc] init] autorelease];
    if (aMessage) 
	{
        NSEnumerator *enumerator = [headers objectEnumerator];
        NSString *fieldName;
        EDHeaderFieldCoder *coder;
        NSString *decodedHeader = nil;
        NSMutableArray *fieldNames = [NSMutableArray array];
        NSMutableArray *fieldValues = [NSMutableArray array];
        
        while (fieldName = [enumerator nextObject])
        {
            if ([fieldName isEqualToString:@"Date"]) 
            {
                NSCalendarDate *myDate;
                
                myDate = [[aMessage date] copy];
                [myDate setTimeZone:[NSTimeZone localTimeZone]];
                
                decodedHeader = [myDate descriptionWithCalendarFormat:@"%A %B %e, %Y (%I:%M %p)"];
                
                [myDate release];
            } 
			else 
			{;
                @try 
				{
                    coder = [aMessage decoderForHeaderFieldNamed:fieldName];
                    decodedHeader = [coder stringValue];
                } 
				@catch(id localException) 
				{
                    decodedHeader = [aMessage bodyForHeaderField:fieldName];
                }
            }
            
            if (decodedHeader) 
			{
                [fieldNames addObject:fieldName];
                [fieldValues addObject:decodedHeader];
            }
        }
        
		/*
		if ([aMessage isSigned])
		{
			[fieldNames addObject:@"Signature"];
			[fieldValues addObject:[aMessage signatureDescription]];
		}
		 */
		
		if (fieldNames.count == 0)
		{
			NSLog(@"No header fields in message? Seems like a severely broken message. %@", self);
		}
		else
		{
			NSMutableAttributedString *fieldTable = [self fieldTableWithRowCount:[fieldNames count]];
			int i, count = [fieldNames count];
			int startPosition = 0;
			
			// replace templates
			for (i = 0; i < count; i++)
			{
				NSRange nameRange = [[fieldTable string] rangeOfString:@"$fieldname$" options:0 range:NSMakeRange(startPosition, [[fieldTable string] length] - startPosition)];
				NSAssert(nameRange.location != NSNotFound, @"name template could not be found");
				NSString *nameString = NSLocalizedString([fieldNames objectAtIndex:i], @"A field name in the message header like 'Subject'");
				[fieldTable replaceCharactersInRange:nameRange withString:nameString];
				
				startPosition = nameRange.location + [nameString length];
				
				NSRange valueRange = [[fieldTable string] rangeOfString:@"$fieldvalue$" options:0 range:NSMakeRange(startPosition, [[fieldTable string] length] - startPosition)];
				NSAssert(valueRange.location != NSNotFound, @"value template could not be found");
				[fieldTable replaceCharactersInRange:valueRange withString:[fieldValues objectAtIndex:i]];
				
				startPosition = valueRange.location + [[fieldValues objectAtIndex:i] length];
			}
			
			[displayString appendAttributedString:fieldTable];
			
			
			// other headers
			if (showOthers) 
			{
				NSEnumerator *enumerator;
				NSArray *headerField;
				
				enumerator = [[aMessage headerFields] objectEnumerator];
				while (headerField = [enumerator nextObject])
				{
					decodedHeader = nil;
					fieldName = [headerField objectAtIndex:0];
					
					if ([headers indexOfObject:fieldName] == NSNotFound) // only when not in standard headers
					{
						if ([aMessage isMultiHeader:headerField])
						{
							// is header field with multiple entries
							decodedHeader = [headerField objectAtIndex:1];
						}
						else
						{
							NS_DURING
                            coder = [aMessage decoderForHeaderFieldNamed:fieldName];
                            decodedHeader = [coder stringValue];
							NS_HANDLER
                            decodedHeader = [aMessage bodyForHeaderField:fieldName];
							NS_ENDHANDLER
						}
						
						if (decodedHeader)
						{
							[self _appendFieldName:fieldName andDecodedHeader:decodedHeader toAttributedString:displayString];
						}
					}
				}
				
				[displayString appendString:@"\n"];
			}
        }
        /*
        if([displayString length] > 0) 
        {
            [displayString appendString: @"\n"];
        }
         */		
    }
    return displayString;
}


+ (NSMutableAttributedString *)renderedBodyForMessage:(OPInternetMessage *)aMessage
{
    NSMutableAttributedString *bodyContent = [aMessage bodyContent];
    // prepare quotations
    [bodyContent prepareQuotationsForDisplay];
    return bodyContent;
}

- (NSAttributedString *)renderedMessageIncludingAllHeaders:(BOOL)allHeaders
/*" Eagerly renderes the internetmessage contained in the receiver. Includes all headers if flag set. Default list if headers otherise. Can be slow! Cache it somewhere! "*/
{
    OPInternetMessage *theMessage = [self internetMessage];
    
    NSMutableAttributedString *messageContent = [[self class] renderedHeaders:[[self class] headersShown] forMessage:theMessage showOthers:allHeaders];   
	
	/*
	NSFileWrapper* paperClip = [[[NSFileWrapper alloc] initWithPath: [[NSBundle mainBundle] pathForResource: @"PaperClip" ofType: @"tiff"] autorelease];
	[messageContent appendAttachmentWithFileWrapper: paperClip
							   showInlineIfPossible: YES];
	*/
		
    if (theMessage) [messageContent appendAttributedString:[[self class] renderedBodyForMessage:theMessage]];
    
    return messageContent;
}

- (NSImage *)personImage
/*"Tries multiple way to aquire an image of the sender. Returns nil, if unsuccessful."*/
{
	/*
    NSImage *cachedImage = [self primitiveValueForKey:@"CachedImage"];
    
    if (!cachedImage) 
    {
        if ([self hasFlags:OPIsFromMeStatus]) 
        {
// ##WARNING put only single to: address image here.
            //cachedImage = [[GIPeopleImageCache sharedInstance] getImageForName: [[theMessage toWithFallback: YES] addressFromEMailString]];
        } 
        else 
        {
            //cachedImage = [[GIPeopleImageCache sharedInstance] getImageForName: [[theMessage replyToWithFallback: YES] addressFromEMailString]];
            NSLog(@"Searching personImage for %@", [[self internetMessage] replyToWithFallback:YES]);
            
            if (!cachedImage) 
            {
                
// disabled for now!
                
                //cachedImage = [NSImage imageWithXFaceData: [[theMessage bodyForHeaderField: @"X-Face"] dataUsingEncoding: NSASCIIStringEncoding]]; // returns nil, if no header exists.
 //if (cachedImage) NSLog(@"Created XFace with checksum %@.", [[cachedImage TIFFRepresentation] md5Checksum]);
            }
        }
        
        [self setPrimitiveValue:cachedImage forKey: @"CachedImage"];
    }
    
    return cachedImage;
	 */
	return nil;
}


+ (NSFont *)font
    /*" Returns the font that is used as base font for message rendering. "*/
{    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *fontName = [userDefaults objectForKey:MessageRendererFontName];
    float fontSize = [userDefaults integerForKey:MessageRendererFontSize];
    
    return fontName ? [NSFont fontWithName:fontName size:fontSize] 
        : [NSFont userFontOfSize:-1];
}

/*" Sets the base font to use for message rendering. "*/
+ (void) setFont:(NSFont *)aFont
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    NSParameterAssert(aFont != nil);
    
    [userDefaults setObject:[aFont fontName] forKey:MessageRendererFontName];
    [userDefaults setInteger:[aFont pointSize] forKey:MessageRendererFontSize];
    
    // synching the content coders' default font
    //[EDContentCoder setDefaultFont:aFont];
    //[self flushCache: nil];
}

/*" Returns if attachments should be rendered inline. "*/
+ (BOOL)shouldRenderAttachmentsInlineIfPossible
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:MessageRendererShouldRenderAttachmentsInlineIfPossible];
}

/*" Sets if attachments should be rendered inline. "*/
+ (void)setShouldRenderAttachmentsInlineIfPossible:(BOOL)aBool
{
    NSUserDefaults *userDefaults;
    
    if (aBool != [self shouldRenderAttachmentsInlineIfPossible]) 
	{
        userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults setBool:aBool forKey:MessageRendererShouldRenderAttachmentsInlineIfPossible];
        
        // synching the content coders' default font
        //[EDContentCoder setShouldRenderAttachmentsInlineIfPossible:aBool];
    }
}

@end

#import <WebKit/WebKit.h>
#import "EDContentCoder.h"
#import "EDPlainTextContentCoder.h"

@interface EDContentCoder (WebResourceSupport)
- (WebArchive *)webArchive;
@end

@implementation EDContentCoder (WebResourceSupport)

- (WebArchive *)webArchive
{
	return nil;
}

@end

@interface NSString (WebResourceSupport)
- (NSString *)stringByConvertingToHTML;
//- (NSString *)HTMLUrlifyInRange:(NSRange)range urlRanges:(NSMutableArray **)urlRanges;
@end

@interface NSAttributedString (WebResourceSupport)
- (NSString *)stringByConvertingToHTML;
@end

@implementation NSAttributedString (WebResourceSupport)

- (NSString *)stringByConvertingToHTML
{
	NSMutableString *result = [NSMutableString string];
	NSString *string = self.string;
	
	NSUInteger quoteLevel = 0;
	[result appendString:@"<p>"];
	
	// fixes the gap problem before the first blockquote
	// (maybe a more experienced css coder can help to avoid this hack):
	[result appendString:@"<blockquote style=\"padding: 0px;\">"];
	[result appendString:@"</blockquote>"];
	
	NSUInteger length = string.length;
	NSUInteger currentPos = 0;
	while (currentPos < length)
	{
		NSRange effectiveRange;
		NSDictionary *attributes = [self attributesAtIndex:currentPos longestEffectiveRange:&effectiveRange inRange:NSMakeRange(currentPos, length - currentPos)];
		NSString *urlString = [attributes objectForKey:NSLinkAttributeName];
		NSUInteger excerptDepth = [[attributes objectForKey:OPQuotationAttributeName] unsignedIntegerValue];
		
		if (urlString)
		{
			// handling URLs:
			[result appendString:@"<a href=\""];
			[result appendString:urlString];
			[result appendString:@"\">"];
			[result appendString:[[string substringWithRange:effectiveRange] stringByConvertingToHTML]];
			[result appendString:@"</a>"];
		}
		else if (quoteLevel != excerptDepth)
		{
			// handling quotes:
			while (quoteLevel < excerptDepth)
			{
				[result appendString:@"<blockquote type=\"cite\">"];
				quoteLevel += 1;
			}
			
			while (quoteLevel > excerptDepth)
			{
				[result appendString:@"</blockquote>"];
				quoteLevel -= 1;
			}
			
			[result appendString:[[string substringWithRange:effectiveRange] stringByConvertingToHTML]];
		}
		else
		{
			// handling normal text:
			[result appendString:[[string substringWithRange:effectiveRange] stringByConvertingToHTML]];
		}
		
		currentPos = MAX(currentPos + 1, NSMaxRange(effectiveRange));
	}
	
	while (quoteLevel > 0)
	{
		[result appendString:@"</blockquote>"];
		quoteLevel -= 1;
	}
	
	[result appendString:@"</p>"];

	return result;
}

@end

@implementation NSString (WebResourceSupport)
- (NSString *)stringByConvertingToHTML
{
	NSString *result = [self stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
	result = [result stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
	result = [result stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
	result = [result stringByReplacingOccurrencesOfString:@"\"" withString:@"&quot;"];
	result = [result stringByReplacingOccurrencesOfString:@"\n\n" withString:@"</p><p>"];
	result = [result stringByReplacingOccurrencesOfString:@"  " withString:@"&nbsp;&nbsp;"];

//	result = [result stringByReplacingOccurrencesOfString:@"\n\n" withString:@"<div><br/></div><div><br/></div>\n"];
	result = [result stringByReplacingOccurrencesOfString:@"\n" withString:@"<br />\n"];
//	result = [result stringByReplacingOccurrencesOfString:@"\n " withString:@"\n&nbsp;"];
//	result = [[@"<p>\n" stringByAppendingString:result] stringByAppendingString:@"\n</p>"];

//	NSMutableArray *urlRanges;
//	
//	result = [result HTMLUrlifyInRange:NSMakeRange(0, [self length]) urlRanges:&urlRanges];
	
	return result;
}

//- (NSString *)HTMLUrlifyInRange:(NSRange)range urlRanges:(NSMutableArray **)urlRanges
//{
//    static NSCharacterSet *colon = nil, *alpha, *urlstop, *ulfurlstop;
//    static NSString *scheme[] = { @"http", @"https", @"ftp", @"mailto", @"gopher", @"news", nil };
//    static unsigned int maxServLength = 6;
//    NSMutableString *string;
//    NSMutableString *url;
//    NSRange	r, remainingRange, possSchemeRange, schemeRange, urlRange, badCharRange;
//    unsigned int nextLocation, endLocation, i;
//    // ulfs stuff
//    BOOL schemeRangeIsAtBeginning = NO;
//    BOOL urlIsWrappedByBrackets = NO;
//    
//	(*urlRanges) = [NSMutableArray array];
//	
//    if(colon == nil)
//    {
//        colon = [[NSCharacterSet characterSetWithCharactersInString: @":"] retain];
//        alpha = [[NSCharacterSet alphanumericCharacterSet] retain];
//        //urlstop = [[NSCharacterSet characterSetWithCharactersInString: @"\"<>()[]',; \t\n\r"] retain];
//        urlstop = [[NSCharacterSet characterSetWithCharactersInString: @"\"<>()[]' \t\n\r"] retain];
//        // if the url is wrapped by brackets we will use this one:
//        ulfurlstop = [[NSCharacterSet characterSetWithCharactersInString: @">"] retain];
//        // problem is that if there is no closing '>' everything until the end of string will be treated as url
//    }
//    
//    string = [self mutableCopy];
//    nextLocation = range.location;
//    endLocation = NSMaxRange(range);
//    while(1)
//    {
//        remainingRange = NSMakeRange(nextLocation, endLocation - nextLocation);
//        r = [string rangeOfCharacterFromSet:colon options:0 range:remainingRange];
//        if(r.length == 0)
//            break;
//        nextLocation = NSMaxRange(r);
//        
//        if(r.location < maxServLength) 
//        {
//            possSchemeRange = NSMakeRange(0, r.location);
//            schemeRangeIsAtBeginning = YES;
//        }    
//        else
//        {
//            possSchemeRange = NSMakeRange(r.location - 6,  6);
//            schemeRangeIsAtBeginning = NO;
//        }
//        // no need to clean up composed chars becasue they are not allowed in URLs anyway
//        for(i = 0; scheme[i] != nil; i++)
//        {
//            schemeRange = [string rangeOfString:scheme[i] options:(NSBackwardsSearch|NSAnchoredSearch|NSLiteralSearch) range:possSchemeRange];
//            if(schemeRange.length != 0)
//            {
//                // if the char before schemeRange is a '<' we need to look for it as the end of the string
//                if ((schemeRange.location > 0) && ([string characterAtIndex:(schemeRange.location - 1)] == '<'))
//                    urlIsWrappedByBrackets = YES;
//                else
//                    urlIsWrappedByBrackets = NO;
//                
//                r.length = endLocation - r.location;
//                
//                // check to determine the correct urlstop CharacterSet
//                if (urlIsWrappedByBrackets)
//                    r = [string rangeOfCharacterFromSet:ulfurlstop options:0 range:r];
//                else
//                    r = [string rangeOfCharacterFromSet:urlstop options:0 range:r];
//                
//                if(r.length == 0) // not found, assume URL extends to end of string
//                    r.location = [string length];
//                urlRange = NSMakeRange(schemeRange.location, r.location - schemeRange.location);
//                if([string characterAtIndex:NSMaxRange(urlRange) - 1] == (unichar)'.')
//                    urlRange.length -= 1;
//                url = [NSMutableString stringWithString:[string substringWithRange:urlRange]];
//                
//                // remove bad characters (like CR LF) from url
//                badCharRange = [url rangeOfCharacterFromSet:urlstop options:0 range:NSMakeRange(0, [url length])];
//                while (badCharRange.location != NSNotFound)
//                {
//                    [url deleteCharactersInRange:badCharRange];
//                    badCharRange = [url rangeOfCharacterFromSet:urlstop options:0 range:NSMakeRange(0, [url length])];
//                }
//                
//				NSString *openAnchorTag = [[@"<a href=\"" stringByAppendingString:url] stringByAppendingString:@"\">"];
//				NSString *closeAnchorTag = @"</a>";
//				
//				[string insertString:openAnchorTag atIndex:urlRange.location];
//				[string insertString:closeAnchorTag atIndex:urlRange.location + urlRange.length + openAnchorTag.length];
//
//				NSRange urlRange = NSMakeRange(urlRange.location, urlRange.location + urlRange.length + openAnchorTag.length + closeAnchorTag.length);
//				
//				[(*urlRanges) addObject:NSStringFromRange(urlRange)];
//				
//                //[self addAttribute:NSLinkAttributeName value:url range:urlRange];
//                nextLocation = NSMaxRange(urlRange);
//                break;
//            }
//        }
//    }
//    
//    return string;
//}

@end

@implementation EDPlainTextContentCoder (WebResourceSupport)

- (WebResource *)webArchive
{
	NSData *data = [[[self attributedString] stringByConvertingToHTML] dataUsingEncoding:NSUTF8StringEncoding];
	NSURL *URL = [NSURL URLWithString:@""];
	NSString *MIMEType = @"text/html";
	NSString *textEncodingName = @"UTF-8";
	
	WebResource *mainResource = [[[WebResource alloc] initWithData:data URL:URL MIMEType:MIMEType textEncodingName:textEncodingName frameName:nil] autorelease];
	
	return [[[WebArchive alloc] initWithMainResource:mainResource subresources:nil subframeArchives:nil] autorelease];
}

@end

#import "OPMultimediaContentCoder.h"

@implementation OPMultimediaContentCoder (WebResourceSupport)

- (WebArchive *)webArchive
{
	BOOL displayInline = shouldBeDisplayedInline;
	
	if (!displayInline)
	{
//		NSString *MIMEType = @"image/tiff";	
//		NSURL *URL = [NSURL URLWithString:@"."];
//		NSString *textEncodingName = nil;
//		NSData *iconData = [[[NSWorkspace sharedWorkspace] iconForFileType:[filename pathExtension]] TIFFRepresentation];
//
//		WebResource *mainResource = [[[WebResource alloc] initWithData:iconData URL:URL MIMEType:MIMEType textEncodingName:textEncodingName frameName:nil] autorelease];
//		return [[[WebArchive alloc] initWithMainResource:mainResource subresources:nil subframeArchives:nil] autorelease];		
//
		
		NSString *MIMEType = @"text/html";	
		NSURL *URL = [NSURL URLWithString:@"http://localhost/index.html"];
		NSString *textEncodingName = @"UTF-8";
		NSData *htmlData = [@"<a href=\"bildchen.tiff\">Bild = <img src=\"/bildchen.tiff\"/></a>" dataUsingEncoding:NSUTF8StringEncoding];
		
		WebResource *mainResource = [[[WebResource alloc] initWithData:htmlData URL:URL MIMEType:MIMEType textEncodingName:textEncodingName frameName:nil] autorelease];
		
		NSURL *subResourceURL = [NSURL URLWithString:@"http://localhost/bildchen.tiff"];
		NSString *pathExtension = [filename pathExtension];
//		NSData *iconData = [[[NSWorkspace sharedWorkspace] iconForFileType:[filename pathExtension]] TIFFRepresentation];
		NSData *iconData = [[[NSWorkspace sharedWorkspace] iconForFileType:pathExtension] TIFFRepresentation];
		
		WebResource *subResource = [[[WebResource alloc] initWithData:iconData URL:subResourceURL MIMEType:@"image/tiff" textEncodingName:nil frameName:nil] autorelease];

		return [[[WebArchive alloc] initWithMainResource:mainResource subresources:[NSArray arrayWithObject:subResource] subframeArchives:nil] autorelease];		
	}
	else
	{
		NSString *MIMEType = @"text/html";
		NSString *textEncodingName = @"UTF-8";
		NSData *htmlData = [[NSString stringWithFormat:@"<p><br/>%@ message part not yet decodable in HTML (should displayed inline = %d).<br/></p>", 
							 [self contentType], shouldBeDisplayedInline] dataUsingEncoding:NSUTF8StringEncoding];
		NSURL *URL = [NSURL URLWithString:@""];
		
		WebResource *mainResource = [[[WebResource alloc] initWithData:htmlData URL:URL MIMEType:MIMEType textEncodingName:textEncodingName frameName:nil] autorelease];
		
		return [[[WebArchive alloc] initWithMainResource:mainResource subresources:nil subframeArchives:nil] autorelease];
	}
}

@end

#import "EDTextContentCoder.h"

@implementation EDTextContentCoder (WebResourceSupport)

- (WebArchive *)webArchive
{
	if ([[part contentType] isEqualToString:@"text/html"])
	{
		NSString *MIMEType = @"text/html";
		NSString *textEncodingName = @"UTF-8";
		NSURL *URL = [NSURL URLWithString:@""];
		NSString *string = [self stringFromMessagePart:part];
		NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];

		WebResource *mainResource = [[[WebResource alloc] initWithData:data URL:URL MIMEType:MIMEType textEncodingName:textEncodingName frameName:nil] autorelease];
		
		return [[[WebArchive alloc] initWithMainResource:mainResource subresources:nil subframeArchives:nil] autorelease];		
	}
	else
	{
		NSString *MIMEType = @"text/html";
		NSString *textEncodingName = @"UTF-8";
		NSData *data = [[NSString stringWithFormat:@"<p><br/>%@ message part not yet decodable in HTML.<br/></p>", [part contentType]] dataUsingEncoding:NSUTF8StringEncoding];
		NSURL *URL = [NSURL URLWithString:@""];
		
		WebResource *mainResource = [[[WebResource alloc] initWithData:data URL:URL MIMEType:MIMEType textEncodingName:textEncodingName frameName:nil] autorelease];
		
		return [[[WebArchive alloc] initWithMainResource:mainResource subresources:nil subframeArchives:nil] autorelease];
	}
	
	return nil;
}

@end

#import "OPMultipartContentCoder.h"

@implementation OPMultipartContentCoder (WebResourceSupport)

- (WebArchive *)webArchiveWithPreferredContentTypes:(NSArray *)preferredContentTypes
{    
	if ([subtype caseInsensitiveCompare:@"alternative"] == NSOrderedSame)
	{
		EDMessagePart *preferredSubpart = [self mostPreferredSubpartWithPreferredContentTypes:preferredContentTypes];
		
		if (preferredSubpart) 
		{
			Class contentCoderClass = [EDContentCoder contentDecoderClass:preferredSubpart];
						
			if (contentCoderClass != nil) // found a content coder willing to decode self
			{
				EDContentCoder *contentCoder = [[contentCoderClass alloc] initWithMessagePart:preferredSubpart];
				
				return [contentCoder webArchive];
			}
		} 
		else 
		{
			NSString *MIMEType = @"text/html";
			NSString *textEncodingName = @"UTF-8";
			NSData *data = [@"<p><br/>multipart/alternative message part with no decodable alternative.<br/></p>" dataUsingEncoding:NSUTF8StringEncoding];
			NSURL *URL = [NSURL URLWithString:@""];

			WebResource *mainResource = [[[WebResource alloc] initWithData:data URL:URL MIMEType:MIMEType textEncodingName:textEncodingName frameName:nil] autorelease];
			
			return [[[WebArchive alloc] initWithMainResource:mainResource subresources:nil subframeArchives:nil] autorelease];
		}
	}
    else if ([subtype caseInsensitiveCompare:@"mixed"] == NSOrderedSame)
	{
		NSString *MIMEType = @"text/html";
		NSString *textEncodingName = @"UTF-8";
		NSMutableData *data = [NSMutableData data];
		NSURL *URL = [NSURL URLWithString:@""];
		NSMutableArray *subresources = [NSMutableArray array];
		
		for (EDMessagePart *subpart in [self subparts])
		{
			Class contentCoderClass = [EDContentCoder contentDecoderClass:subpart];
			
			if (contentCoderClass != nil) // found a content coder willing to decode self
			{
				EDContentCoder *contentCoder = [[contentCoderClass alloc] initWithMessagePart:subpart];
				
				WebArchive *archive = [contentCoder webArchive];
				if (archive)
				{
					[data appendData:[[archive mainResource] data]];
					[subresources addObjectsFromArray:[archive subresources]];
				}
				else
				{
					[data appendData:[[NSString stringWithFormat:@"<p><br/>no resource for subpart %@.<br/></p>", [subpart contentType]] dataUsingEncoding:NSUTF8StringEncoding]];
				}
			}
		}
		
		WebResource *mainResource = [[[WebResource alloc] initWithData:data URL:URL MIMEType:MIMEType textEncodingName:textEncodingName frameName:nil] autorelease];

		return [[[WebArchive alloc] initWithMainResource:mainResource subresources:nil subframeArchives:nil] autorelease];
	}

	return nil;
}

- (WebArchive *)webArchive
{
	return [self webArchiveWithPreferredContentTypes:nil];
}

@end

@implementation OPInternetMessage (WebResourceSupport)

- (WebArchive *)webArchive
{
	EDContentCoder *coder = [[[[EDContentCoder contentDecoderClass:self] alloc] initWithMessagePart:self] autorelease];
	
	WebArchive *archive = [coder webArchive];
								 
	NSString *contentString = [[[NSString alloc] initWithData:[[archive mainResource] data] encoding:NSUTF8StringEncoding] autorelease];
	
	NSString *cssString = @"<style type=\"text/css\"><!--\nbody {\n"
	@"font-size : 9pt;\n" 
	@"font-family : Arial, Helvetica, sans-serif;\n" 
	@"font-weight : normal;\n"
	@"color : #000000;\n" 
	@"padding-bottom: 2px;"
  	@"}\n"
	@"blockquote[type=cite] {"
	@"border-left: 2px solid #0080FF;"
	@"background-color: #F2F1FF;"
	@"margin: 0px;"
	@"padding-top: 2px;"
	@"padding-left: 6px;"
	@"padding-bottom: 2px;"
	@"}"
	@"blockquote[type=cite] blockquote[type=cite] {"
	@"border-left: 2px solid #FF8000;"
	@"background-color: #FFFEED;"
	@"}"
	@"blockquote[type=cite] blockquote[type=cite] blockquote[type=cite] {"
	@"border-left: 2px solid #008040;"
	@"background-color: #EEFFF2;"
	@"}"
	@"blockquote[type=cite] blockquote[type=cite] blockquote[type=cite] blockquote[type=cite] {"
	@"border-left: 2px solid #0080FF;"
	@"background-color: #F2F1FF;"
	@"}"
	@"blockquote[type=cite] blockquote[type=cite] blockquote[type=cite] blockquote[type=cite] blockquote[type=cite] {"
	@"border-left: 2px solid #FF8000;"
	@"background-color: #FFFEED;"
	@"}"
	@"--></style>\n";
	
	NSString *htmlContent = contentString;
//	if ([contentString rangeOfString:@"<html" options:NSCaseInsensitiveSearch].location == NSNotFound)
	{
		htmlContent = [NSString stringWithFormat:@"<html><head><meta http-equiv=\"Content-type\" content=\"text/html;charset=UTF-8\" />%@</head><body>%@</body></html>", cssString, contentString];
	}

	NSData *data = [htmlContent dataUsingEncoding:NSUTF8StringEncoding];
	NSURL *URL = [NSURL URLWithString:@""];
	NSString *MIMEType = @"text/html";
	NSString *textEncodingName = @"UTF-8";
	
	WebResource *mainResource = [[[WebResource alloc] initWithData:data URL:URL MIMEType:MIMEType textEncodingName:textEncodingName frameName:nil] autorelease];
	
	WebArchive *result = [[[WebArchive alloc] initWithMainResource:mainResource subresources:[archive subresources] subframeArchives:nil] autorelease];
								   
	return result;
}

@end

