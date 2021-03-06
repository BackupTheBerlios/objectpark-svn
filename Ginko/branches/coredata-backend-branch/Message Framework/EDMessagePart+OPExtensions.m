/* 
     $Id: EDMessagePart+OPExtensions.m,v 1.7 2005/05/13 09:25:34 mikesch Exp $

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
*/

#import "EDMessagePart+OPExtensions.h"
//#import "EDMessagePart+OPMboxExtensions.h"
//#import "EDContentCoder+OPExtensions.h"
#import "OPContentCoderCenter.h"
#import "OPDebug.h"
#import "NSString+MessageUtils.h"
//#import "EDObjectPair.h"
#import "OPMultimediaContentCoder.h"
#import "OPApplefileContentCoder.h"
#import "OPAppleDoubleContentCoder.h"
#import "OPMultipartContentCoder.h"
#import "OPXFolderContentCoder.h"
#import "EDPLainTextContentCoder.h"
#import "utilities.h"
#import "EDTextContentCoder.h" // can be removed

@interface EDMessagePart(PrivateAPI)
+ (NSDictionary *)_defaultFallbackHeaders;
- (NSData *)takeHeadersFromData:(NSData *)data;
@end



/*
@implementation EDMessagePart (TemporaryBugFix)

// bufix: made robust for unknown content transfer encodings -> fallback to 7bit
- (id)initWithTransferData:(NSData *)data fallbackHeaderFields:(NSDictionary *)fields
{
    NSString	*cte;
    NSData	  	*rawData;

    [super init];
    
    if(fields != nil)
        {
        fallbackFields = [[NSMutableDictionary allocWithZone:[self zone]] initWithDictionary:[[self class] _defaultFallbackHeaders]];
        [(NSMutableDictionary *)fallbackFields addEntriesFromDictionary:fields];
        }
    else
        {
        fallbackFields = [[[self class] _defaultFallbackHeaders] retain];
        }

    if([data length] == 0)
        return self;

    rawData = [self takeHeadersFromData:data];
    cte = [[(EDTextFieldCoder *)[EDTextFieldCoder decoderWithFieldBody:[self bodyForHeaderField:@"content-transfer-encoding"]] text] stringByRemovingSurroundingWhitespace];
    
    NS_DURING
        [self setContentData:[rawData decodeContentWithTransferEncoding:cte]];
    NS_HANDLER
        // fallback to 7bit encoding
        [self setContentData:[rawData decodeContentWithTransferEncoding:MIME7BitContentTransferEncoding]];
    NS_ENDHANDLER

    return self;
}
*/

/*
- (NSString *)contentDisposition
{
    NSString 			*fBody;
    EDEntityFieldCoder	*coder;

    if((contentDisposition == nil) && ((fBody = [self bodyForHeaderField:@"content-disposition"]) != nil))
        {
        coder = [EDEntityFieldCoder decoderWithFieldBody:fBody];
        contentDisposition = [[[coder values] objectAtIndex:0] retain];
        contentDispositionParameters = [[coder parameters] retain];
        }
    return contentDisposition;
}
*/

/* Waht is the improvement over the EDM version?

// make resistent agains missing header to body separators
- (NSData *)takeHeadersFromData:(NSData *)data
{
    const char		 *p, *pmax, *fnamePtr, *fbodyPtr, *eolPtr;
    NSMutableData	 *fbodyData;
    NSString 		 *name, *fbodyContents;
    EDObjectPair	 *field;
    NSRange		 bodyRange;
    NSStringEncoding encoding;

#warning * default NSISOLatin1StringEncoding for headers?!
    encoding = NSISOLatin1StringEncoding;
    name = nil;
    fnamePtr = p = [data bytes];
    pmax = p + [data length];
    fbodyPtr = NULL;
    fbodyData = nil;
    for(;p < pmax; p++)
    {
        if((*p == COLON) && (fbodyPtr == NULL))
        {
            fbodyPtr = p + 1;
            if((fbodyPtr < pmax) && (iswhitespace(*fbodyPtr)))
            {
                fbodyPtr += 1;
            }
            name = [NSString stringWithCString:fnamePtr length:(p - fnamePtr)];
        }
        else if(iscrlf(*p))
        {
            if (fbodyPtr != NULL) // only if it's a real header
            {
                eolPtr = p;
                p = skipnewline(p, pmax);
                if((p < pmax) && iswhitespace(*p)) // folded header!
                {
                    if(fbodyData == nil)
                    {
                        fbodyData = [NSMutableData dataWithBytes:fbodyPtr length:(eolPtr - fbodyPtr)];
                    }
                    else
                    {
                        [fbodyData appendBytes:fbodyPtr length:(eolPtr - fbodyPtr)];
                    }
                    fbodyPtr = p;
                }
                else
                {
                    if(fbodyData == nil)
                    {
                        fbodyData = (id)[NSData dataWithBytes:fbodyPtr length:(eolPtr - fbodyPtr)];
                    }
                    else
                    {
                        [fbodyData appendBytes:fbodyPtr length:(eolPtr - fbodyPtr)];
                    }
                    fbodyContents = [NSString stringWithData:fbodyData encoding:encoding];
                    // we know something about the implementation of addToHeaderFields
                    // by uniqueing the string here we avoid creating another pair.
                    name = [name sharedInstance];
                    field = [[EDObjectPair allocWithZone:[self zone]] initWithObjects:name:fbodyContents];
                    [self addToHeaderFields:field];
                    [field release];
                    fbodyData = nil;
                    fnamePtr = p;
                    fbodyPtr = NULL;
                    if((p < pmax) && iscrlf(*p))
                    {
                        break;
                    }
                }
            }
            else // broken header -> broken message -> last line was a body line
            {
                if(fnamePtr > pmax)
                {
                    return nil;
                }
                bodyRange = NSMakeRange(fnamePtr - (char *)[data bytes], pmax - fnamePtr);
                return [data subdataWithRange:bodyRange];
            }
        }
    }
    p = skipnewline(p, pmax);
    if(p > pmax)
        return nil;
    bodyRange = NSMakeRange(p - (char *)[data bytes], pmax - p);
    return [data subdataWithRange:bodyRange];
}

@end
*/

@implementation EDMessagePart (OPBehaviorChange)


/*
#warning axel->axel: submit to Erik
- (NSData *)transferData
{
    NSMutableData	 		*transferData;
    NSData					*headerData;
    NSMutableString			*stringBuffer;
    NSEnumerator			*fieldEnum;
    EDObjectPair			*field;


    // Make sure we have some encoding set that we can use:
    if (![contentData canCodeWithTransferEncoding: [self contentTransferEncoding]]) {
        // Fall back to MIME8BitContentTransferEncoding:
        NSLog(@"Warning: Substituting illegal content-transfer-encoding '%@'.", [self contentTransferEncoding]);
        [self setContentTransferEncoding: MIME8BitContentTransferEncoding];
    }
    // We now have a valid transfer encoding set.
    
    transferData = [NSMutableData data];

    stringBuffer = [NSMutableString string];
    fieldEnum = [[self headerFields] objectEnumerator];
    while((field = [fieldEnum nextObject]) != nil)
        {
        NSMutableString *headerLine;

        headerLine = [[NSMutableString alloc] initWithString:[field firstObject]];
//        [stringBuffer appendString:[field firstObject]];
        [headerLine appendString:@": "];
        [headerLine appendString:[field secondObject]];
        [headerLine appendString:@"\r\n"];

        [stringBuffer appendString:[headerLine stringByFoldingStringToLimit:998]];

        [headerLine release];
        }
    [stringBuffer appendString:@"\r\n"];
    
    if (! [stringBuffer canBeConvertedToEncoding:NSASCIIStringEncoding])
    {
        OPDebugLog2(MESSAGEDEBUG, OPWARNING, @"-[%@ %@]: Transfer representation of header fields contains non ASCII characters. Fallback to lossy conversion.", NSStringFromClass(isa), NSStringFromSelector(_cmd));
    }
        
    if((headerData = [stringBuffer dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES]) == nil)
    {
        [NSException raise:NSInternalInconsistencyException format:@"-[%@ %@]: Error converting header data to ASCII encoding (despite of use of lossy conversion).", NSStringFromClass(isa), NSStringFromSelector(_cmd)];
    }
    
    [transferData appendData:headerData];

    [transferData appendData:[contentData encodeContentWithTransferEncoding: [self contentTransferEncoding]]];
    
    return transferData;
}
*/

@end

@implementation EDMessagePart (OPExtensions)


+ (NSArray*) preferredContentTypes
/*" Forwards preferredContentTypes to NSApp delegate. Returns a default array of content type strings as default. "*/
{
    static id defaultTypes = nil;
    if ([[NSApp delegate] respondsToSelector: @selector(preferredContentTypes)]) 
    {
        return [[NSApp delegate] preferredContentTypes];
    }
    
    if (!defaultTypes) {
        defaultTypes = [[NSArray alloc] initWithObjects: 
            @"multipart/mixed", 
            @"text/enriched", 
            @"text/plain", 
            @"text/html", nil];
    }
    
    return defaultTypes;
}

- (Class)contentDecoderClass
{
    // deciding which content coder to use
    return [OPContentCoderCenter contentDecoderClass:self];
}

- (NSAttributedString *)contentAsAttributedString
{
    return [self contentAsAttributedStringWithPreferredContentTypes:nil];
}

- (NSAttributedString *)contentAsAttributedStringWithPreferredContentTypes:(NSArray *)preferredContentTypes
/*" Returns the receivers content as a user presentable attributed string. Returns nil if not decodable. "*/
{
    NSAttributedString* content = nil;
    Class contentCoderClass;
    
    contentCoderClass = [self contentDecoderClass];
    
    //if (NSDebugEnabled) NSLog(@"Using DecoderClass = %@", contentCoderClass);
    
    if (contentCoderClass != nil) // found a content coder willing to decode self
    {
        EDContentCoder* contentCoder = [[contentCoderClass alloc] initWithMessagePart:self];
        

        @try {

            if ([contentCoder respondsToSelector:@selector(attributedStringWithPreferredContentTypes:)]) {
                content = [(id)contentCoder attributedStringWithPreferredContentTypes:preferredContentTypes];
                [content retain];
            } else {
                content = [contentCoder attributedString];
                [content retain];
            }
        } @catch (NSException* localException) {
            OPDebugLog3(MESSAGEDEBUG, OPERROR, @"[%@ %@] Exception while extracting contents as attributed string. (%@)", [self class], NSStringFromSelector(_cmd), [localException reason]);
            content = [[[NSAttributedString alloc] initWithString:@"Exception while extracting contents as attributed string."] autorelease];
        } @finally {
        }
        
//#warning debug only
//        [contentCoder autorelease];
        [contentCoder release];
    }
    
    if (! content) {
        NSMutableAttributedString* result = [[NSMutableAttributedString alloc] initWithString: [NSString stringWithFormat: @"--- Content of type %@ could not be decoded. Falling back to text/plain: ---\n\n", [self contentType]]];
        // Fake text/plain for the content coder to work:
        [self setContentType: @"text/plain" withParameters: [NSDictionary dictionary]];

        EDContentCoder* contentCoder = [[EDPlainTextContentCoder alloc] initWithMessagePart:self];

        @try {
            [result appendAttributedString: [contentCoder attributedString]];
            content = result;
        } @catch (NSException* localException) {
            OPDebugLog3(MESSAGEDEBUG, OPERROR, @"[%@ %@] Exception while extracting contents as attributed string. (%@)", [self class], NSStringFromSelector(_cmd), [localException reason]);
            content = [[NSAttributedString alloc] initWithString:@"Exception while extracting contents as attributed string."];
        }

        [contentCoder release];
        

    }
    return [content autorelease];
}

- (NSString *)contentAsPlainString
/*" Returns the contents as a plain text string. Rich content is described as plain text. Suitable for fulltext indexing of the body content (not including the header texts). "*/
{
	// TODO: Improve! This is a very naive implementation
	return [[self contentAsAttributedString] string];
}

@end

/*
@implementation EDMessagePart (Tests)

- (void)testTakeHeaders
{
    NSString *testString = @"From Hein Bloed\n\tfold me sucker\nSubject: Sowas\nContent-Type: multipart/mixed;\n   boundary=\"----_=_NextPart_000_01C12EF4.7146FC60\"\nThis message is in MIME format. Since your mail reader does not understand\nthis format, some or all of this message may not be legible.";

    NSLog(@"message string = %@", testString);
    [[[EDMessagePart alloc] initWithMboxData:[testString dataUsingEncoding:NSISOLatin1StringEncoding]] autorelease];
}

+ (id)testFixture
{
    return [[[EDMessagePart alloc] init] autorelease];
}

+ (id)testSelectors
{
    return [NSArray arrayWithObjects: @"testTakeHeaders", nil];
}

- (void)testTeardown
{
}

- (void)testSetup
{
}


@end
*/