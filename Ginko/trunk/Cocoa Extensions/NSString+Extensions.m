//---------------------------------------------------------------------------------------
//  NSString+printf.m created by erik on Sat 27-Sep-1997
//  @(#)$Id: NSString+Extensions.m,v 1.6 2005/04/01 23:38:11 theisen Exp $
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

//#ifndef EDCOMMON_WOBUILD
//#import <AppKit/AppKit.h>
//#endif
//#ifdef EDCOMMON_OSXBUILD
#import <CoreFoundation/CoreFoundation.h>
//#endif
#import <Foundation/Foundation.h>
#import "NSString+Extensions.h"

#include <sys/types.h>
#include <sys/stat.h>
#include <stdio.h>
//#include <ctype.h>
#include <string.h>
#include <libxml/xmlmemory.h>
#include <libxml/HTMLparser.h>

#ifndef WIN32
#import <unistd.h>
#else
#define random() rand()
#endif

@interface NSString(EDExtensionsPrivateAPI)
+ (NSDictionary *)_contentTypeExtensionMapping;
@end


//=======================================================================================
    @implementation NSString(EDExtensions)
//=======================================================================================

/*" Various common extensions to #NSString. "*/

NSString *MIMEAsciiStringEncoding = @"us-ascii";
NSString *MIMELatin1StringEncoding = @"iso-8859-1";
NSString *MIMELatin2StringEncoding = @"iso-8859-2";
NSString *MIME2022JPStringEncoding = @"iso-2022";
NSString *MIMEUTF8StringEncoding = @"utf-8";

NSString *MIMEApplicationContentType = @"application";
NSString *MIMEImageContentType		 = @"image";
NSString *MIMEAudioContentType		 = @"audio";
NSString *MIMEMessageContentType 	 = @"message";
NSString *MIMEMultipartContentType 	 = @"multipart";
NSString *MIMETextContentType 		 = @"text";
NSString *MIMEVideoContentType       = @"video";

NSString *MIMEAlternativeMPSubtype 	 = @"alternative";
NSString *MIMEMixedMPSubtype 		 = @"mixed";
NSString *MIMEParallelMPSubtype 	 = @"parallel";
NSString *MIMEDigestMPSubtype 		 = @"digest";
NSString *MIMERelatedMPSubtype 		 = @"related";

NSString *MIMEInlineContentDisposition = @"inline";
NSString *MIMEAttachmentContentDisposition = @"attachment";


static NSFileHandle *stdoutFileHandle = nil;
static NSLock *printfLock = nil;
static NSCharacterSet *iwsSet = nil;


//---------------------------------------------------------------------------------------
//	CONVENIENCE CONSTRUCTORS
//---------------------------------------------------------------------------------------

/*" Convenience factory method. "*/

+ (NSString*) stringWithData: (NSData*) data encoding:(NSStringEncoding)encoding
{
    return [[[NSString alloc] initWithData:data encoding:encoding] autorelease];
}




//---------------------------------------------------------------------------------------
//	VARIOUS EXTENSIONS
//---------------------------------------------------------------------------------------

/*" Returns a copy of the receiver with all whitespace left of the first non-whitespace character and right of the last whitespace character removed. "*/

//- (NSString*) stringByRemovingSurroundingWhitespace
//{
//	return [self stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];

	/*
    NSRange		start, end, result;

    if(iwsSet == nil)
        iwsSet = [[[NSCharacterSet whitespaceCharacterSet] invertedSet] retain];

    start = [self rangeOfCharacterFromSet:iwsSet];
    if(start.length == 0)
        return @""; // string is empty or consists of whitespace only

    end = [self rangeOfCharacterFromSet:iwsSet options:NSBackwardsSearch];
    if((start.location == 0) && (end.location == [self length] - 1))
        return self;

    result = NSMakeRange(start.location, end.location + end.length - start.location);

    return [self substringWithRange:result];	
	 */
//}


/*" Returns YES if the receiver consists of whitespace only. "*/

- (BOOL)isWhitespace
{
    if(iwsSet == nil)
        iwsSet = [[[NSCharacterSet whitespaceCharacterSet] invertedSet] retain];

    return ([self rangeOfCharacterFromSet:iwsSet].length == 0);

}


/*" Returns a copy of the receiver with all whitespace removed. "*/

- (NSString*) stringByRemovingWhitespace
{
    return [self stringByRemovingCharactersFromSet:[NSCharacterSet whitespaceCharacterSet]];
}


- (NSString *)stringWithCanonicalLinebreaks
/*" Returns an autoreleased copy of the receiver with single LF chars replaced by CRLF. "*/
{
    unsigned length = [self length];
    NSMutableString *result = nil;
    unichar lastChr = 0;
    unichar chr;
    int i;
    
    for (i = 0; i<length;i++) 
	{
        chr = [self characterAtIndex:i];
        if (chr == LF && lastChr!=CR) 
		{
            if (!result) 
			{
                result = [[self mutableCopy] autorelease];
                [result deleteCharactersInRange: NSMakeRange(i, length-i)];
            }
            [result appendString:@"\r\n"];
        } 
		else 
		{
            [result appendFormat:@"%C", chr];
        }
        lastChr = chr;
    }
    return result ? result : self;
}

- (NSString*) stringWithUnixLinebreaks
	/*" Returns an autoreleased copy of the receiver with CRLF chars replaced by single LF. "*/
{
    unsigned length = [self length];
    NSMutableString *result = nil;
    unichar lastChr = 0;
    unichar chr;
    int i;
    
    for (i = 0; i < length; i++) 
    {
        chr = [self characterAtIndex:i];
        
        if (chr == LF && lastChr == CR) 
        {
            if (!result) 
            {
                result = [[self mutableCopy] autorelease];
                [result deleteCharactersInRange:NSMakeRange(i - 1, length -(i - 1))];
            }
            else
            {
                [result deleteCharactersInRange:NSMakeRange([result length] - 1, 1)];
            }
            [result appendString: @"\n"];
        } 
        else 
        {
            [result appendFormat: @"%C",chr];
        }
        lastChr = chr;
    }
    return result ? result : self;
}

- (NSString*) stringByRemovingLinebreaks
/*" Warning: Simplistic implementation - slow. "*/
{
    NSString* lineBreakSeq = @"\r\n";
    if([self rangeOfString:lineBreakSeq].length == 0)
        lineBreakSeq = @"\n";
    
    return [[self componentsSeparatedByString:lineBreakSeq] componentsJoinedByString: @""];
}


/*" Returns a copy of the receiver with all characters from %set removed. "*/

- (NSString*) stringByRemovingCharactersFromSet: (NSCharacterSet*) set
{
    NSMutableString	*temp;

    if([self rangeOfCharacterFromSet:set options:NSLiteralSearch].length == 0)
        return self;
    temp = [[self mutableCopyWithZone:[self zone]] autorelease];
    [temp removeCharactersInSet:set];

    return temp;
}


/*" Returns YES if the receiver's prefix is equal to %string, comparing case insensitive. "*/

- (BOOL)hasPrefixCaseInsensitive: (NSString*) string
{
    return (([string length] <= [self length]) && ([self compare:string options:(NSCaseInsensitiveSearch|NSAnchoredSearch) range:NSMakeRange(0, [string length])] == NSOrderedSame));
}


/*" Returns YES if the receiver is equal to string "yes", comparing case insensitive. "*/
- (BOOL) boolValue
{
    if([self intValue] > 0)
        return YES;
    return [self caseInsensitiveCompare: @"yes"] == NSOrderedSame;
}

- (long long) longLongValue
{
	char buffer[100];
	[self getCString: buffer maxLength: 99];
	return atoll(buffer);
}

/*" Assumes the string contains an integer written in hexadecimal notation and returns its value. Uses #scanHexInt in #NSScanner. "*/
- (unsigned int)intValueForHex {
    unsigned int value;

    if([[NSScanner scannerWithString:self] scanHexInt:&value] == NO)
        return 0;
    
    return value;
}


/*" Returns yes if the string contains no text characters. Note that its length can still be non-zero. "*/
- (BOOL)isEmpty {
    return [self isEqualToString: @""];
}


//---------------------------------------------------------------------------------------
//	FACTORY METHODS
//---------------------------------------------------------------------------------------

/*" Creates and returns a string by converting the bytes in data using the string encoding described by %charsetName. If no NSStringEncoding corresponds to %charsetName this method returns !{nil}. "*/

+ (NSString*) stringWithData: (NSData*) data MIMEEncoding: (NSString*) charsetName
{
    return [[[NSString alloc] initWithData:data MIMEEncoding:charsetName] autorelease];
}


/*" Creates and returns a string by copying %length characters from %buffer and coverting these into a string using the string encoding described by %charsetName. If no NSStringEncoding corresponds to %charsetName this method returns !{nil}. "*/

+ (NSString*) stringWithBytes:(const void *)buffer length:(unsigned int)length MIMEEncoding: (NSString*) charsetName
{
    return [[[NSString alloc] initWithData:[NSData dataWithBytes:buffer length:length] MIMEEncoding:charsetName] autorelease];
}

// HTML Stripping!

/*
#define MAX_TAGNAMELENGTH 20
#define MAX_STRIPTAGS 20

typedef struct Stripper {
	int f_in_tag;
	int f_closing;
	int f_lastchar_slash;
	
	char tagname[MAX_TAGNAMELENGTH];
	char * p_tagname;
	char f_full_tagname;
	
	int f_outputted_space;
	int f_just_seen_tag;
	
	int f_in_quote;
	char quote;
	
	int f_in_decl;
	int f_in_comment;
	int f_lastchar_minus;
	
	int f_in_striptag;
	char striptag[MAX_TAGNAMELENGTH];
	char o_striptags[MAX_STRIPTAGS][MAX_TAGNAMELENGTH];
	int numstriptags;
	int o_emit_spaces;
	int o_decode_entities;
} Stripper;

void strip_html( Stripper * stripper, const char * raw, char * clean );

void clear_striptags( Stripper * stripper );
void add_striptag( Stripper * stripper, char * tag );

static void check_end( Stripper * stripper, char end ) {
	// if current character is a slash, may be a closed tag 
	if( end == '/' ) {
		stripper->f_lastchar_slash = 1;
	} else {
		// if the current character is a '>', then the tag has ended 
		if( end == '>' ) {
			stripper->f_in_quote = 0;
			stripper->f_in_comment = 0;
			stripper->f_in_decl = 0;
			stripper->f_in_tag = 0;
			// Do not start a stripped tag block if the tag is a closed one, e.g. '<script src="foo" />' 
			if( stripper->f_lastchar_slash &&
				(strcasecmp( stripper->striptag, stripper->tagname ) == 0) ) {
				stripper->f_in_striptag = 0;
			}
		}
		stripper->f_lastchar_slash = 0;
	}
}


void strip_html( Stripper * stripper, const char * raw, char * output ) {
	const char * p_raw = raw;
	const char * raw_end = raw + strlen(raw);
	char * p_output = output;
    
	while( p_raw < raw_end ) {
		if( stripper->f_in_tag ) {
			// inside a tag 
			// check if we know either the tagname, or that we're in a declaration 
			if( !stripper->f_full_tagname && !stripper->f_in_decl ) {
				// if this is the first character, check if it's a '!'; if so, we're in a declaration 
				if( stripper->p_tagname == stripper->tagname && *p_raw == '!' ) {
					stripper->f_in_decl = 1;
				}
				// then check if the first character is a '/', in which case, this is a closing tag 
				else if( stripper->p_tagname == stripper->tagname && *p_raw == '/' ) {
					stripper->f_closing = 1;
				} else {
					// if we don't have the full tag name yet, add current character unless it's whitespace, a '/', or a '>';
					// otherwise null pad the string and set the full tagname flag, and check the tagname against stripped ones.
					// also sanity check we haven't reached the array bounds, and truncate the tagname here if we have 
					if( (!isspace( *p_raw ) && *p_raw != '/' && *p_raw != '>') &&
						!( (stripper->p_tagname - stripper->tagname) == MAX_TAGNAMELENGTH ) ) {
						*stripper->p_tagname++ = *p_raw;
					} else {
						*stripper->p_tagname = 0;
						stripper->f_full_tagname = 1;
						// if we're in a stripped tag block, and this is a closing tag, check to see if it ends the stripped block 
						if( stripper->f_in_striptag && stripper->f_closing ) {
							if( strcasecmp( stripper->tagname, stripper->striptag ) == 0 ) {
								stripper->f_in_striptag = 0;
							}
							// if we're outside a stripped tag block, check tagname against stripped tag list 
						} else if( !stripper->f_in_striptag && !stripper->f_closing ) {
							int i;
							for( i = 0; i <= stripper->numstriptags; i++ ) {
								if( strcasecmp( stripper->tagname, stripper->o_striptags[i] ) == 0 ) {
									stripper->f_in_striptag = 1;
									strcpy( stripper->striptag, stripper->tagname );
								}
							}
						}
						check_end( stripper, *p_raw );
					}
				}
			} else {
				if( stripper->f_in_quote ) {
					// inside a quote 
					// end of quote if current character matches the opening quote character 
					if( *p_raw == stripper->quote ) {
						stripper->quote = 0;
						stripper->f_in_quote = 0;
					}
				} else {
					// not in a quote 
					// check for quote characters 
					if( *p_raw == '\'' || *p_raw == '\"' ) {
						stripper->f_in_quote = 1;
						stripper->quote = *p_raw;
						// reset lastchar_* flags in case we have something perverse like '-"' or '/"' 
						stripper->f_lastchar_minus = 0;
						stripper->f_lastchar_slash = 0;
					} else {
						if( stripper->f_in_decl ) {
							// inside a declaration 
							if( stripper->f_lastchar_minus ) {
								// last character was a minus, so if current one is, then we're either entering or leaving a comment 
								if( *p_raw == '-' ) {
									stripper->f_in_comment = !stripper->f_in_comment;
								}
								stripper->f_lastchar_minus = 0;
							} else {
								// if current character is a minus, we might be starting a comment marker 
								if( *p_raw == '-' ) {
									stripper->f_lastchar_minus = 1;
								}
							}
							if( !stripper->f_in_comment ) {
								check_end( stripper, *p_raw );
							}
						} else {
							check_end( stripper, *p_raw );
						}
					} // quote character check 
				} // in quote check 
			} // full tagname check 
		}
    else {
		// not in a tag 
		// check for tag opening, and reset parameters if one has 
		if( *p_raw == '<' ) {
			stripper->f_in_tag = 1;
			stripper->tagname[0] = 0;
			stripper->p_tagname = stripper->tagname;
			stripper->f_full_tagname = 0;
			stripper->f_closing = 0;
			stripper->f_just_seen_tag = 1;
		}
		else {
			// copy to stripped provided we're not in a stripped block 
			if( !stripper->f_in_striptag ) {
				// only emit spaces if we're configured to do so (on by default) 
				if( stripper->o_emit_spaces ){
					// output a space in place of tags we have previously parsed,
					and set a flag so we only do this once for every group of tags.
					done here to prevent unnecessary trailing spaces 
					if( isspace(*p_raw) ) {
						// don't output a space if this character is one anyway 
						stripper->f_outputted_space = 1;
					} else {
						if( !stripper->f_outputted_space &&
							stripper->f_just_seen_tag ) {
							*p_output++ = ' ';
							stripper->f_outputted_space = 1;
						} else {
							// this character must not be a space 
							stripper->f_outputted_space = 0;
						}
					}
				}
				*p_output++ = *p_raw;
				// reset 'just seen tag' flag 
				stripper->f_just_seen_tag = 0;
			}
		}
    } // in tag check 
    p_raw++;
	} // while loop 

  *p_output = 0;
}

static void reset_stripper( Stripper * stripper ) {
	stripper->f_in_tag = 0;
	stripper->f_closing = 0;
	stripper->f_lastchar_slash = 0;
	stripper->f_full_tagname = 0;
	// hack to stop a space being output on strings starting with a tag 
	stripper->f_outputted_space = 1;
	stripper->f_just_seen_tag = 0;
    
	stripper->f_in_quote = 0;
	
	stripper->f_in_decl = 0;
	stripper->f_in_comment = 0;
	stripper->f_lastchar_minus = 0;
    
	stripper->f_in_striptag = 0;
}

void clear_striptags( Stripper * stripper ) {
	strcpy(stripper->o_striptags[0], "");
	stripper->numstriptags = 0;
}

void add_striptag( Stripper * stripper, char * striptag ) {
	if( stripper->numstriptags < MAX_STRIPTAGS-1 ) {
		strcpy(stripper->o_striptags[stripper->numstriptags++], striptag);
	} else {
		fprintf( stderr, "Cannot have more than %i strip tags", MAX_STRIPTAGS );
	}
}

 - (NSString*) stringByStrippingHTML2
 {
	 const char* source = [self UTF8String];
	 char* dest = malloc([self length]*3/2);
	 Stripper stripper;
	 reset_stripper(&stripper);
	 clear_striptags(&stripper);
	 strip_html(&stripper, source, dest);
	 NSString* result = [NSString stringWithUTF8String: dest];
	 free(dest);
	 return result;
 }
 
*/


static void charactersParsed(void* context, const xmlChar * ch, int len)
/*" Callback function for stringByStrippingHTML. "*/
{
	NSMutableString* result = context;
	
	NSString* parsedString;
	parsedString = [[NSString alloc] initWithBytesNoCopy: (xmlChar*) ch
												  length: len 
												encoding: NSUTF8StringEncoding 
											freeWhenDone: NO];
	[result appendString: parsedString];
	[parsedString release];
}


- (NSString*) stringByStrippingHTML
/*" interpretes the receiver als HTML and removes all tags and converts it to plain text. "*/
{
	
	int mem_base = xmlMemBlocks();

	NSMutableString* result = [NSMutableString string];
	xmlSAXHandler handler; bzero(&handler, sizeof(xmlSAXHandler)); // null structure
	handler.characters = &charactersParsed;
	
	htmlSAXParseDoc((xmlChar*)[self UTF8String], "utf-8", &handler, result);

	if (mem_base != xmlMemBlocks()) {
		printf("Leak of %d blocks found in htmlSAXParseDoc",
	           xmlMemBlocks() - mem_base);
	}
		
	
	return result;
}



//---------------------------------------------------------------------------------------
//	Converting to/from byte representations
//---------------------------------------------------------------------------------------

/*" Initialises a newly allocated string by converting the bytes in buffer using the string encoding described by %charsetName. If no NSStringEncoding corresponds to %charsetName this method returns !{nil}. "*/

- (id)initWithData: (NSData*) buffer MIMEEncoding: (NSString*) charsetName
{
    NSStringEncoding encoding;

    if((encoding = [NSString stringEncodingForMIMEEncoding:charsetName]) == 0)
        return nil; // Behaviour has changed (2001/08/03).
    return [self initWithData:buffer encoding:encoding];
}


/*" Returns an NSData object containing a representation of the receiver in the encoding described by %charsetName. If no NSStringEncoding corresponds to %charsetName this method returns !{nil}. "*/

- (NSData*) dataUsingMIMEEncoding: (NSString*) charsetName
{
    NSStringEncoding encoding;

    if((encoding = [NSString stringEncodingForMIMEEncoding:charsetName]) == 0)
        return nil;
    return [self dataUsingEncoding:encoding];
}


//---------------------------------------------------------------------------------------
//	NSStringEncoding vs. MIME Encoding
//---------------------------------------------------------------------------------------

#ifdef __COREFOUNDATION__

+ (NSStringEncoding)stringEncodingForMIMEEncoding: (NSString*) charsetName
{
    CFStringEncoding cfEncoding;

    if(charsetName == nil)
        return 0;

    charsetName = [charsetName lowercaseString];
    cfEncoding = CFStringConvertIANACharSetNameToEncoding((CFStringRef)charsetName);
    if(cfEncoding == kCFStringEncodingInvalidId)
        return 0;
    return CFStringConvertEncodingToNSStringEncoding(cfEncoding);
}


+ (NSString*) MIMEEncodingForStringEncoding:(NSStringEncoding)nsEncoding
{
    CFStringEncoding cfEncoding;

    cfEncoding = CFStringConvertNSStringEncodingToEncoding(nsEncoding);
    return (NSString*) CFStringConvertEncodingToIANACharSetName(cfEncoding);
}


- (NSString*) recommendedMIMEEncoding
{
    static NSStringEncoding preferredEncodings[] = {
        NSASCIIStringEncoding, NSISOLatin1StringEncoding, NSISOLatin2StringEncoding,
        // no constants available for ISO8859-3 through ISO8859-15
        2147484163U, 2147484164U, 2147484165U, 2147484166U, 2147484167U,
        2147484168U, 2147484169U, 2147484170U, 2147484171U, 2147484173U,
        2147484174U, 2147484175U, 0 };
    NSStringEncoding *encodingPtr;

    for(encodingPtr = preferredEncodings; *encodingPtr != 0; encodingPtr++)
        {
        if([self canBeConvertedToEncoding:*encodingPtr])
            return [NSString MIMEEncodingForStringEncoding:*encodingPtr];
        }

    return [NSString MIMEEncodingForStringEncoding:[self smallestEncoding]];
}

#else

/*" Returns the NSStringEncoding corresponding to the MIME character set %charsetName or 0 if no such encoding exists. On Mac OS X this wraps #CFStringConvertIANACharSetNameToEncoding and on other platforms hardcoded tables are used. "*/

+ (NSStringEncoding)stringEncodingForMIMEEncoding: (NSString*) encoding
{
    static NSMutableDictionary	*table = nil;

    if(table == nil)
        {
        table = [NSMutableDictionary dictionary];
        [table setObject: [NSNumber numberWithUnsignedInt:NSASCIIStringEncoding] forKey:MIMEAsciiStringEncoding];
        [table setObject: [NSNumber numberWithUnsignedInt:NSISOLatin1StringEncoding] forKey:MIMELatin1StringEncoding];
        [table setObject: [NSNumber numberWithUnsignedInt:NSISOLatin2StringEncoding] forKey:MIMELatin2StringEncoding];
        [table setObject: [NSNumber numberWithUnsignedInt:NSISO2022JPStringEncoding] forKey:MIME2022JPStringEncoding];
        [table setObject: [NSNumber numberWithUnsignedInt:NSUTF8StringEncoding] forKey:MIMEUTF8StringEncoding];
        [table setObject: [NSNumber numberWithUnsignedInt:NSWindowsCP1252StringEncoding] forKey: @"windows-1252"];
        table = [table copy];
        }
    return [[table objectForKey:[encoding lowercaseString]] unsignedIntValue];
}


/*" Returns the MIME character set corresponding to the NSStringEncoding or !{nil} if no such encoding exists. On Mac OS X this wraps #CFStringConvertEncodingToIANACharSetName and on other platforms hardcoded tables are used. "*/

+ (NSString*) MIMEEncodingForStringEncoding:(NSStringEncoding)encoding
{
    static NSMutableDictionary	*table = nil;

    if(table == nil)
        {
        table = [NSMutableDictionary dictionary];
        [table setObject: MIMEAsciiStringEncoding forKey:[NSNumber numberWithUnsignedInt:NSASCIIStringEncoding]];
        [table setObject: MIMELatin1StringEncoding forKey:[NSNumber numberWithUnsignedInt:NSISOLatin1StringEncoding]];
        [table setObject: MIMELatin2StringEncoding forKey:[NSNumber numberWithUnsignedInt:NSISOLatin2StringEncoding]];
        [table setObject: MIME2022JPStringEncoding forKey:[NSNumber numberWithUnsignedInt:NSISO2022JPStringEncoding]];
        [table setObject: MIMEUTF8StringEncoding forKey:[NSNumber numberWithUnsignedInt:NSUTF8StringEncoding]];
        [table setObject: @"windows-1252" forKey:[NSNumber numberWithUnsignedInt:NSWindowsCP1252StringEncoding]];
        table = [table copy];
        }
    return [table objectForKey:[NSNumber numberWithUnsignedInt:encoding]];
}


/*" Returns the encoding, specified as a MIME character set, that the receiver should be converted to when being transferred on the Internet. This method prefers ASCII over ISO-Latin over the smallest encoding. "*/

- (NSString*) recommendedMIMEEncoding
{
    if([self canBeConvertedToEncoding:NSASCIIStringEncoding])
        return MIMEAsciiStringEncoding;
    if([self canBeConvertedToEncoding:NSISOLatin1StringEncoding])
        return MIMELatin1StringEncoding;
    if([self canBeConvertedToEncoding:NSISOLatin2StringEncoding])
        return MIMELatin2StringEncoding;
    if([self canBeConvertedToEncoding:NSISO2022JPStringEncoding])
        return MIME2022JPStringEncoding;
    if([self canBeConvertedToEncoding:NSUTF8StringEncoding])
        return MIMEUTF8StringEncoding;
    return nil;
}

#endif


//---------------------------------------------------------------------------------------
//	TYPE / FILENAME EXTENSION MAPPING
//---------------------------------------------------------------------------------------

static NSMutableDictionary *teTable = nil;


+ (NSDictionary *)_contentTypeExtensionMapping
{
    NSString *path;
    
    if(teTable == nil)
    {
        // the following bundle description sucks big time, what to do?
        path = [[NSBundle bundleForClass:NSClassFromString(@"GIApplication")] pathForResource: @"MIME" ofType:@"plist"];
        teTable = [[[NSString stringWithContentsOfFile:path] propertyList] retain];
        NSAssert([teTable isKindOfClass:[NSDictionary class]], @"Problem with MIME.plist");
    }
    return teTable;
}


/*" Returns a file extension that is used for files of the MIME content type/subtype. Note that one MIME type might be represented by several file extensions. "*/

+ (NSString*) pathExtensionForContentType: (NSString*) contentType
{
    NSDictionary   	*table;
    NSEnumerator	*extensionEnum;
    NSString		*extension;

    contentType = [contentType lowercaseString];
    table = [self _contentTypeExtensionMapping];
    extensionEnum = [table keyEnumerator];
    while((extension = [extensionEnum nextObject]) != nil)
        {
        if([[table objectForKey:extension] isEqualToString:contentType])
            break;
        }
    return extension;
}


/*" Returns the MIME content type/subtype for extension "*/

+ (NSString*) contentTypeForPathExtension: (NSString*) extension
{
    return [[self _contentTypeExtensionMapping] objectForKey:[extension lowercaseString]];
}


//---------------------------------------------------------------------------------------
//	XML DOCUMENT ENCODING
//---------------------------------------------------------------------------------------

/*" Examines %xmlData and searches for an XML processing directive that specifies the document's encoding. If found returns the encoding, specified as a MIME character set, otherwise returns !{nil}. "*/

+ (NSString*) MIMEEncodingOfXMLDocument: (NSData*) xmlData
{
    NSScanner			*scanner;
    NSString			*pd, *encoding;
    NSRange				pdRange;
    const char 			*p, *pmax, *pdStart;
    short				inQuotes;

    p = [xmlData bytes];
    pmax = p + [xmlData length];

    // skip initial whitespace, return *nil* if document is completely empty
    while((p < pmax) && (isspace(*p)))
        p += 1;
    if(p == pmax)
        return nil;

    // grab processing directive
    if((p + 6 >= pmax) || (*p != '<') || (*p == '?'))
        [NSException raise:NSGenericException format: @"Could not find processing directive in XML doc."];
    pdStart = p + 2;
    inQuotes = 0;
    for(p = pdStart;p < pmax; p++)
        {
        if(*p == '"')
            inQuotes ^= 1;
        else if((*p == '>') && (inQuotes == 0))
            break;
        }
    if((p == pmax) || (*(p - 1) != '?'))
        [NSException raise:NSGenericException format: @"Malformed processing directive in XML doc."];
    pdRange = NSMakeRange((int)pdStart - (int)[xmlData bytes], (int)p - 1 - (int)pdStart);
    pd = [NSString stringWithData:[xmlData subdataWithRange:pdRange] encoding:NSASCIIStringEncoding];

    // analyse and find encoding value
    scanner = [NSScanner scannerWithString:pd];
    if([scanner scanString: @"xml" intoString: NULL] == NO)
        [NSException raise:NSGenericException format: @"Could not find processing directive in XML doc."];
    if([scanner scanUpToString: @"encoding" intoString: NULL] == NO || [scanner isAtEnd])
        {
        encoding = MIMEUTF8StringEncoding;
        }
    else
        {
        [scanner scanString: @"encoding" intoString: NULL];
        if(([scanner scanString: @"=" intoString: NULL] == NO) ||
           ([scanner scanString: @"\"" intoString: NULL] == NO) ||
           ([scanner scanUpToString: @"\"" intoString:&encoding] == NO))
            [NSException raise:NSGenericException format: @"Malformed processing directive in XML doc."];
        }
    return encoding;
}


/*" Examines %xmlData and searches for an XML processing directive that specifies the document's encoding. If found returns the encoding, specified as an NSStringEncoding, otherwise returns 0. "*/

+ (NSStringEncoding)encodingOfXMLDocument: (NSData*) xmlData
{
    return [self stringEncodingForMIMEEncoding:[self MIMEEncodingOfXMLDocument:xmlData]];
}



#ifndef WIN32 // [TRH 2001/01/18] quick hack: disabled since Windows does not have crypt()
//---------------------------------------------------------------------------------------
//	CRYPTING
//---------------------------------------------------------------------------------------

/*" Returns an encrypted version of the receiver using a random "salt."

This method is thread-safe.

Note: This method is not available on Windows NT platforms. "*/

- (NSString*) encryptedString
{
    char 	salt[3];

    salt[0] = 'A' + random() % 26;
    salt[1] = 'A' + random() % 26;
    salt[2] = '\0';

    return [self encryptedStringWithSalt:salt];
}

/*
static BOOL _fileExists(char* filePath) 
{
    struct stat stats;
    int result;
    
    if (! filePath) {
        return NO;
    }
    
    result = stat(filePath, &stats);
    if ( (result != 0) && (errno == ENOENT) ) {
        return NO; // file does not exist.
    }
    
    NSCAssert1(result == 0, @"Error while getting file size (stat): %s", strerror(errno));
    return YES;
}
*/


+ (NSString*) temporaryFilenameWithPrefix: (NSString*) prefix 
/*" Only 7 bit strings are allowed for prefix and ext parameters. The file does not yes exist. "*/
{
	if (!prefix) prefix = @"";
	char* result = (char*)[[NSString stringWithFormat: @"%@/%@-XXXXXXX", NSTemporaryDirectory(), prefix] cString];

	result = mktemp(result);
    
	return [NSString stringWithCString: result];
}



- (NSString*) encryptedStringWithSalt:(const char *)salt
/*" Returns an encrypted version of the receiver using %salt as randomizer. %Salt must be a C String containing excatly two characters.
	This method is thread-safe. Note: This method is not available on Windows NT platforms. "*/
{
    static NSLock	*encryptLock = nil;
    NSMutableData 	*sdata;
    char 			*encryptedCString;
    NSString 		*encryptedString;
    char 			terminator = '\0';

    NSParameterAssert((salt != NULL) && (strlen(salt) == 2));

    if(encryptLock == nil)
        encryptLock = [[NSLock alloc] init]; // intentional leak

    sdata = [[self dataUsingEncoding:NSNonLossyASCIIStringEncoding] mutableCopy];
    [sdata appendBytes:&terminator length:1];

    [encryptLock lock];
    encryptedCString = crypt((const char *)[sdata bytes], (const char *)salt);
    encryptedString = [[[NSString allocWithZone:[self zone]] initWithCString:encryptedCString] autorelease];
    [encryptLock unlock];

    [sdata release];
    
    return encryptedString;
}


/*" Returns YES if the receiver is a encryption of %aString. Assume you have the encrypted password in !{pwd} and the user's input in !{input}. Call !{[pwd isValidEncryptionOfString:input]} to verify the passwrd.

This method is thread-safe.

Note: This method is not available on Windows NT platforms. "*/

- (BOOL)isValidEncryptionOfString: (NSString*) aString
{
  char salt[3];

  [self getCString:salt maxLength:2];
  salt[2] = '\0';
  return [self isEqualToString:[aString encryptedStringWithSalt:salt]];
}
#endif // !defined(WIN32)


//---------------------------------------------------------------------------------------
//	SHARING STRING INSTANCES
//---------------------------------------------------------------------------------------

/*" Maintains a global pool of string instances. Returns the instance stored in the pool or adds the receiver if no such string was in the pool before. This can be used to allow for equality tests using #{==} instead of #{isEqual:} but this "leaks" all string instances that are ever shared and, hence, should be used with caution. "*/

- (NSString*) sharedInstance
{
	return self;
	/*
    static NSMutableSet *stringPool;
    NSString *sharedInstance;

    if(stringPool == nil)
        stringPool = [[NSMutableSet alloc] init];

    if((sharedInstance = [stringPool member:self]) != nil)
        return sharedInstance;
    [stringPool addObject:self];
    return self;
	 */
}


//---------------------------------------------------------------------------------------
//	PRINTING
//---------------------------------------------------------------------------------------

/*" Writes the %printf format string to %stdout using the default C String encoding. "*/

+ (void) printf: (NSString*) format, ...
{
    va_list   	args;
    NSString	*buffer;

    va_start(args, format);
    buffer = [[NSString alloc] initWithFormat:format arguments:args];
    [buffer printf];
    [buffer release];
    va_end(args);
}


/*" Writes the %printf format string to %fileHandle using the default C String encoding. "*/

+ (void) fprintf: (NSFileHandle*) fileHandle: (NSString*) format, ...
{
    va_list   	args;
    NSString	*buffer;

    va_start(args, format);
    buffer = [[NSString alloc] initWithFormat:format arguments:args];
    [buffer fprintf:fileHandle];
    [buffer release];
    va_end(args);
}


/*" Writes the contents of the reciever to %stdout using the default C String encoding. "*/

- (void) printf
{
    if(printfLock == nil)
        printfLock = [[NSLock alloc] init];

    [printfLock lock];
    if(stdoutFileHandle == nil)
        stdoutFileHandle = [[NSFileHandle fileHandleWithStandardOutput] retain];
    [stdoutFileHandle writeData:[self dataUsingEncoding:[NSString defaultCStringEncoding]]];
    [printfLock unlock];
}


/*" Writes the contents of the reciever to %fileHandle using the default C String encoding. "*/

- (void) fprintf: (NSFileHandle*) fileHandle
{
    if(printfLock == nil)
        printfLock = [[NSLock alloc] init];

    [printfLock lock];
    [fileHandle writeData:[self dataUsingEncoding:[NSString defaultCStringEncoding]]];
    [printfLock unlock];
}


//=======================================================================================
    @end
//=======================================================================================


//=======================================================================================
    @implementation NSMutableString(EDExtensions)
//=======================================================================================

/*" Various common extensions to #NSMutableString. "*/

/*" Removes all whitespace left of the first non-whitespace character and right of the last whitespace character. "*/

- (void) removeSurroundingWhitespace
{
    NSRange		start, end;

    if(iwsSet == nil)
        iwsSet = [[[NSCharacterSet whitespaceCharacterSet] invertedSet] retain];

    start = [self rangeOfCharacterFromSet:iwsSet];
    if(start.length == 0)
        {
        [self setString: @""];  // string is empty or consists of whitespace only
        return;
        }

    if(start.location > 0)
        [self deleteCharactersInRange:NSMakeRange(0, start.location)];
    
    end = [self rangeOfCharacterFromSet:iwsSet options:NSBackwardsSearch];
    if(end.location < [self length] - 1)
        [self deleteCharactersInRange:NSMakeRange(NSMaxRange(end), [self length] - NSMaxRange(end))];
}


/*" Removes all whitespace from the string. "*/

- (void) removeWhitespace
{
    [self removeCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

/*
- (NSString*) sharedInstance 
{
	NSString* copy = [[self copy] autorelease];
	NSString* result = [copy sharedInstance];
	[copy release];
	return result;
}
*/


/*" Removes all characters in %set from the string. "*/

- (void) removeCharactersInSet: (NSCharacterSet*) set
{
    NSRange			matchRange, searchRange, replaceRange;
    unsigned int    length;

    length = [self length];
    matchRange = [self rangeOfCharacterFromSet:set options:NSLiteralSearch range:NSMakeRange(0, length)];
    while(matchRange.length > 0)
        {
        replaceRange = matchRange;
        searchRange.location = NSMaxRange(replaceRange);
        searchRange.length = length - searchRange.location;
        for(;;)
            {
            matchRange = [self rangeOfCharacterFromSet:set options:NSLiteralSearch range:searchRange];
            if((matchRange.length == 0) || (matchRange.location != searchRange.location))
                break;
            replaceRange.length += matchRange.length;
            searchRange.length -= matchRange.length;
            searchRange.location += matchRange.length;
            }
        [self deleteCharactersInRange:replaceRange];
        matchRange.location -= replaceRange.length;
        length -= replaceRange.length;
        }
}

inline NSString *makeStringIfNil(NSString *str)
/*"Utility function that returns the empty string in case of a nil parameter, str otherwise."*/
{
    return str ? str : @"";
}





//=======================================================================================
@end
//=======================================================================================

