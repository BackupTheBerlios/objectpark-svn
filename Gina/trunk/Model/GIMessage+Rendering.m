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

@implementation GIMessage (Rendering)
/*" Renders a message as an attributed string. This includes header lines as defined in the preferences (plus the default ones). */


static NSArray* _headersShown = nil;

+ (NSArray*) headersShown
    /*" Returns an array of all the header names that Ginko is set up to display (if existent). "*/
{
    if (!_headersShown) 
    {
        _headersShown = [[NSArray arrayWithObjects:
            @"From",
            @"Newsgroups",
            @"Subject",
            @"To",
            @"Cc",
            @"Bcc",
            @"Reply-To",
            @"Date",
            nil] retain];
    }
    return _headersShown;
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
        [[NSMutableAttributedString alloc] initWithString:string];
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

+ (NSMutableAttributedString *)renderedHeaders:(NSArray*) headers forMessage:(OPInternetMessage *)aMessage showOthers:(BOOL)showOthers
/*" Returns empty string if aMessage is nil. "*/
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
		
#warning Exception occurs when [fieldNames count] delivers 0!
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


+ (NSFont*) font
    /*" Returns the font that is used as base font for message rendering. "*/
{    
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    NSString* fontName = [userDefaults objectForKey: MessageRendererFontName];
    float     fontSize = [userDefaults integerForKey: MessageRendererFontSize];
    
    return fontName ? [NSFont fontWithName:fontName size:fontSize] 
        : [NSFont userFontOfSize:-1];
}

+ (void) setFont: (NSFont*) aFont
    /*" Sets the base font to use for message rendering. "*/
{
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    
    NSParameterAssert(aFont != nil);
    
    [userDefaults setObject: [aFont fontName] forKey: MessageRendererFontName];
    [userDefaults setInteger:[aFont pointSize] forKey: MessageRendererFontSize];
    
    // synching the content coders' default font
    //[EDContentCoder setDefaultFont:aFont];
    //[self flushCache: nil];
}

+ (BOOL) shouldRenderAttachmentsInlineIfPossible
    /*" Returns if attachments should be rendered inline. "*/
{
    return [[NSUserDefaults standardUserDefaults] boolForKey: MessageRendererShouldRenderAttachmentsInlineIfPossible];
}

+ (void) setShouldRenderAttachmentsInlineIfPossible: (BOOL)aBool
    /*" Sets if attachments should be rendered inline. "*/
{
    NSUserDefaults *userDefaults;
    
    if (aBool != [self shouldRenderAttachmentsInlineIfPossible]) {
        userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults setBool:aBool forKey: MessageRendererShouldRenderAttachmentsInlineIfPossible];
        
        // synching the content coders' default font
        //[EDContentCoder setShouldRenderAttachmentsInlineIfPossible:aBool];
    }
}



@end
