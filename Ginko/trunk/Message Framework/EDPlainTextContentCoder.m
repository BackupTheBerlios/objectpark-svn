//---------------------------------------------------------------------------------------
//  EDPlainTextContentCoder.m created by erik on Sun 18-Apr-1999
//  @(#)$Id: EDPlainTextContentCoder.m,v 1.10 2005/05/03 10:26:50 theisen Exp $
//
//  Copyright (c) 1997-1999 by Erik Doernenburg. All rights reserved.
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
#import "NSString+MessageUtils.h"
#import "NSData+MessageUtils.h"
#import "EDMessagePart.h"
#import "OPInternetMessage.h"
#import "EDPlainTextContentCoder.h"
#import "GIMessage+Rendering.h"
#import "NSAttributedString+MessageUtils.h"
#import "MPWDebug.h"

@interface EDPlainTextContentCoder(PrivateAPI)
- (void) _takeTextFromMessagePart: (EDMessagePart*) mpart;
- (id)_encodeTextWithClass:(Class)targetClass;
@end


//---------------------------------------------------------------------------------------
    @implementation EDPlainTextContentCoder
//---------------------------------------------------------------------------------------

//---------------------------------------------------------------------------------------
//	CAPABILITIES
//---------------------------------------------------------------------------------------

+ (BOOL) canDecodeMessagePart: (EDMessagePart*) mpart
{
    NSString	*charset;
    
    if([[mpart contentType] isEqualToString: @"text/plain"] == NO)
        return NO;

    charset = [[mpart contentTypeParameters] objectForKey: @"charset"];
    if((charset != nil) && ([NSString stringEncodingForMIMEEncoding:charset] == 0))
        return NO;

    return YES;
}

//---------------------------------------------------------------------------------------
//	INIT & DEALLOC
//---------------------------------------------------------------------------------------

- (id) initWithMessagePart: (EDMessagePart*) mpart
{
    if (self = [self init]) {
        if ([[mpart contentType] hasPrefix: @"text"])
            [self _takeTextFromMessagePart:mpart];
    }
    return self;
}


- (id)initWithText: (NSString*) someText
{
    if (self = [self init]) {
        text = [someText retain];
    }
    return self;
}


- (void) dealloc
{
    [text release]; text = nil;
    [super dealloc];
}


//---------------------------------------------------------------------------------------
//	CONTENT ATTRIBUTES
//---------------------------------------------------------------------------------------

- (NSString*) text
{
    return text;
}


- (EDMessagePart *)messagePart
{
    return [self _encodeTextWithClass:[EDMessagePart class]];
}


- (OPInternetMessage *)message
{
    return [self _encodeTextWithClass:[OPInternetMessage class]];
}


//---------------------------------------------------------------------------------------
//	CODING ATTRIBUTES
//---------------------------------------------------------------------------------------

- (void) setDataMustBe7Bit:(BOOL)flag
{
    dataMustBe7Bit = flag;
}


- (BOOL)dataMustBe7Bit
{
    return dataMustBe7Bit;
}


//---------------------------------------------------------------------------------------
//	CODING
//---------------------------------------------------------------------------------------

+ (BOOL)canEncodeAttributedString: (NSAttributedString*) anAttributedString atIndex:(int)anIndex effectiveRange:(NSRangePointer)effectiveRange
/*" Decides if anAttributedString can be encoded starting at anIndex. If YES is returned effectiveRange 
    designates the range which can be encoded by this class. If NO is returned effectiveRange indicates
    the range which can not be encoded by this class. "*/
{
    NSRange limitRange;
    id attributeValue;
    
    limitRange = NSMakeRange(anIndex, [anAttributedString length] - anIndex);
    
    attributeValue = [anAttributedString attribute:NSAttachmentAttributeName atIndex:anIndex longestEffectiveRange:effectiveRange inRange:limitRange];
    
    return (attributeValue == nil); // can encode if not an attachment at index anIndex
}

- (void) _takeTextFromMessagePart: (EDMessagePart*) mpart
{
    NSString *charset, *format;
    NSData *contentData;
    
    contentData = [mpart contentData];
    // MPWDebugLog(@"contentData length= %lu", [contentData length]);
    // test if contentData exists
    if ([contentData length] > INT_MAX)
    {
        text = @"";
        return;
    }
    
    if((charset = [[mpart contentTypeParameters] objectForKey: @"charset"]) == nil)
        charset = MIMEAsciiStringEncoding;
    
    if((text = [NSString stringWithData:[mpart contentData] MIMEEncoding:charset]) == nil)
    {
        MPWDebugLog(@"cannot decode charset %@", charset);
        return;
    }
    [text retain];
    
    format = [[mpart contentTypeParameters] objectForKey: @"format"];
    if ((format != nil) && ([format caseInsensitiveCompare: @"flowed"] == NSOrderedSame))
    {
        BOOL useDelSp = NO;
        NSString *delsp;
        NSString *deflowed;
        
        delsp = [[mpart contentTypeParameters] objectForKey: @"delsp"];
        if ((delsp != nil) && ([delsp caseInsensitiveCompare: @"yes"] == NSOrderedSame))
        {
            useDelSp = YES;
        }
        
        deflowed = [[text stringByDecodingFlowedUsingDelSp:useDelSp] retain];
        [text release];
        text = deflowed;
    }
}

- (id)_encodeTextWithClass:(Class)targetClass
{
    EDMessagePart *result;
    NSString *charset, *flowedText;
    NSDictionary *parameters;
    NSData *contentData;
    
    flowedText = [[text stringWithCanonicalLinebreaks] stringByEncodingFlowedFormat];
    
    NSLog(@"Encoding Text with Class %@", targetClass);
    
    result = [[[targetClass alloc] init] autorelease];
    charset = [flowedText recommendedMIMEEncoding];
    parameters = [NSDictionary dictionaryWithObjectsAndKeys:charset ,@"charset", @"flowed", @"format", nil];
    [result setContentType: @"text/plain" withParameters:parameters];
    if([charset caseInsensitiveCompare:MIMEAsciiStringEncoding] == NSOrderedSame)
        [result setContentTransferEncoding:MIME7BitContentTransferEncoding];
    else if(dataMustBe7Bit)
        [result setContentTransferEncoding:MIMEQuotedPrintableContentTransferEncoding];
    else
        [result setContentTransferEncoding:MIME8BitContentTransferEncoding];
    contentData = [flowedText dataUsingMIMEEncoding:charset];
    [result setContentData:contentData];
    
    return result;
}



- (id)initWithAttributedString: (NSAttributedString*) anAttributedString
{
    NSRange effectiveRange;
    
    if (! [[self class] canEncodeAttributedString:anAttributedString atIndex:0 effectiveRange:&effectiveRange])
    {
        [self dealloc];
        NSLog(@"EDPlainTextContentCoder can't encode attributedString '%@'.", anAttributedString);
        return nil;
    }
    
    if (self = [self initWithText: [[anAttributedString string] stringWithUnixLinebreaks]]) {
        [self setDataMustBe7Bit: YES]; // ensure 7bit compatibility
    }
    return self;
}

- (NSAttributedString *)attributedString
{
    NSMutableAttributedString* result = [[[self text] attributedStringWithQuotationAttributes] mutableCopy];
        
    [result addAttribute:NSFontAttributeName value:[GIMessage font] range:NSMakeRange(0, [result length])];
    
    [result urlify];
    
    return [result autorelease];
}

//---------------------------------------------------------------------------------------
    @end
//---------------------------------------------------------------------------------------
