//---------------------------------------------------------------------------------------
//  EDMessagePart.m created by erik on Mon 20-Jan-1997
//  @(#)$Id: EDMessagePart.m,v 1.3 2005/04/14 08:58:12 mikesch Exp $
//
//  Copyright (c) 1999-2000 by Erik Doernenburg. All rights reserved.
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
#import <Foundation/NSDebug.h>
#import "utilities.h"
#import "NSString+MessageUtils.h"
#import "NSData+MessageUtils.h"
#import "EDTextFieldCoder.h"
#import "EDEntityFieldCoder.h"
#import "EDMessagePart.h"
//#import "OPObjectPair.h"
#import "NSString+Extensions.h"

@interface EDMessagePart(PrivateAPI)
+ (NSDictionary *)_defaultFallbackHeaders;
- (NSRange)takeHeadersFromData:(NSData *)data;
- (void)_takeContentDataFromOriginalTransferData;
- (void)_forgetOriginalTransferData;
@end

//---------------------------------------------------------------------------------------
    @implementation EDMessagePart
//---------------------------------------------------------------------------------------


//---------------------------------------------------------------------------------------
//	INIT & DEALLOC
//---------------------------------------------------------------------------------------
- (id)initWithTransferData:(NSData *)data
{
    return [self initWithTransferData:data fallbackHeaderFields:nil];
}

- (id)initWithTransferData:(NSData *)data fallbackStringEncoding:(NSStringEncoding)encoding
{
    NSDictionary *fields;
    NSString *charset, *value;

    charset = [NSString MIMEEncodingForStringEncoding:encoding];
    value = [[[[EDEntityFieldCoder alloc] initWithValue:@"text/plain" andParameters:[NSDictionary dictionaryWithObject:charset forKey:@"charset"]] autorelease] fieldBody];
    fields = [NSDictionary dictionaryWithObject:value forKey:@"content-type"];

    return [self initWithTransferData:data fallbackHeaderFields:fields];
}

- (id)initWithTransferData:(NSData *)data fallbackHeaderFields:(NSDictionary *)fields
/*" Designated Initializer. "*/
{
    self = [self init];
    
    if (fields != nil)
    {
        fallbackFields = [[NSMutableDictionary allocWithZone:[self zone]] initWithDictionary:[[self class] _defaultFallbackHeaders]];
        [(NSMutableDictionary *)fallbackFields addEntriesFromDictionary:fields];
    } 
    else 
    {
        fallbackFields = [[[self class] _defaultFallbackHeaders] retain];
    }
    
    if ((data == nil) || ([data length] == 0))
        return self;
    
    bodyRange = [self takeHeadersFromData:data];
    originalTransferData = [data retain];
    
    return self;
}

- (void)dealloc
{
    bodyRange = NSMakeRange(0, 0);   // do not convert transferData...
    [fallbackFields release];
    [contentType release];
    [contentTypeParameters release];
    [contentData release];
    [originalTransferData release];
    [super dealloc];
}

//---------------------------------------------------------------------------------------
//	TRANSFER LEVEL ACCESSOR METHODS
//---------------------------------------------------------------------------------------

- (NSData *)transferData
{
    if(originalTransferData != nil) return originalTransferData;

    // Make sure we have an encoding that we can use (we fall back to MIME 8Bit)
    if([contentData isValidTransferEncoding:[self contentTransferEncoding]] == NO)
        [self setContentTransferEncoding:MIME8BitContentTransferEncoding];

    NSMutableData *transferData = [NSMutableData data];

    NSMutableString	*stringBuffer = [NSMutableString string];
	
	for (NSArray *field in [self headerFields])
    {
        NSMutableString	*headerLine = [[NSMutableString alloc] initWithString:[field objectAtIndex:0]];
        [headerLine appendString:@": "];
        [headerLine appendString:[field objectAtIndex:1]];
        [headerLine appendString:@"\r\n"];
        [stringBuffer appendString:[headerLine stringByFoldingToLimit:998]];
        [headerLine release];
    }

    [stringBuffer appendString:@"\r\n"];
	
    NSData *headerData;
    if ((headerData = [stringBuffer dataUsingEncoding:NSASCIIStringEncoding]) == nil)
    {
        NSLog(@"-[%@ %@]: Transfer representation of header fields contains non ASCII characters. Fallback to lossy encoding.", NSStringFromClass(isa), NSStringFromSelector(_cmd));
        headerData = [stringBuffer dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion: YES];
    }
    [transferData appendData:headerData];

    [transferData appendData:[contentData encodeContentWithTransferEncoding:[self contentTransferEncoding]]];

    return transferData;
}



//---------------------------------------------------------------------------------------
//	OVERRIDES
//---------------------------------------------------------------------------------------

- (NSString*) bodyForHeaderField: (NSString*) name
{
    NSString *fieldBody;

    if((fieldBody = [super bodyForHeaderField:name]) == nil)
        fieldBody = [fallbackFields objectForKey:[name lowercaseString]];

    return fieldBody;
}

- (void) removeHeaderField: (NSString*) fieldName
{
    [self _forgetOriginalTransferData];
    [super removeHeaderField:fieldName];
}

- (void) setBody: (NSString*) fieldBody forHeaderField: (NSString*) fieldName
{
    [self _forgetOriginalTransferData];
    [super setBody:fieldBody forHeaderField:fieldName];
}

- (void)addToHeaderFieldsName:(NSString *)aName body:(NSString *)aBody
{
	[self _forgetOriginalTransferData];
	[super addToHeaderFieldsName:aName body:aBody];
}

- (void)addToHeaderFields:(NSArray *)headerField
{
    [self _forgetOriginalTransferData];
    [super addToHeaderFieldsName:[headerField objectAtIndex:0] body:[headerField objectAtIndex:1]];
}

//---------------------------------------------------------------------------------------
//	CONTENT TYPE ACCESSOR METHODS
//---------------------------------------------------------------------------------------

- (void) setContentType: (NSString*) aType
{
    [self setContentType:aType withParameters: nil];
}


- (void) setContentType: (NSString*) aType withParameters: (NSDictionary*) someParameters
{
    EDEntityFieldCoder *fCoder;

    [aType retain];
    [contentType release];
    contentType = aType;
    [someParameters retain];
    [contentTypeParameters release];
    contentTypeParameters = someParameters;

    fCoder = [[EDEntityFieldCoder alloc] initWithValue: aType andParameters:contentTypeParameters];
    [self setBody:[fCoder fieldBody] forHeaderField: @"Content-Type"];
    [fCoder release];
}


- (NSString*) contentType
{
    NSString *fBody = [self bodyForHeaderField: @"content-type"];
    EDEntityFieldCoder *coder;
    
    if ((contentType == nil) && fBody != nil) {
        coder = [EDEntityFieldCoder decoderWithFieldBody:fBody];
        contentType = [[coder value] retain];
        contentTypeParameters = [[coder parameters] retain];
    }
    return contentType;
}


- (NSDictionary *)contentTypeParameters
{
    [self contentType];
    return contentTypeParameters;
}


//---------------------------------------------------------------------------------------
//	CONTENT TYPE ACCESSOR METHODS
//---------------------------------------------------------------------------------------

- (void) setContentDisposition: (NSString*) aDispositionDirective
{
    [self setContentDisposition:aDispositionDirective withParameters: nil];
}


- (void) setContentDisposition: (NSString*) aDispositionDirective withParameters: (NSDictionary*) someParameters
{
    EDEntityFieldCoder* fCoder;

    [aDispositionDirective retain];
    [contentDisposition release];
    contentDisposition = aDispositionDirective;
    [someParameters retain];
    [contentDispositionParameters release];
    contentDispositionParameters = someParameters;

    fCoder = [[EDEntityFieldCoder alloc] initWithValue: contentDisposition 
                                         andParameters: contentDispositionParameters];
    [self setBody:[fCoder fieldBody] forHeaderField: @"Content-Disposition"];
    [fCoder release];
}


- (NSString*) contentDisposition
{
    NSString* fBody;
    EDEntityFieldCoder* coder;
    
    if((contentDisposition == nil) && ((fBody = [self bodyForHeaderField: @"content-disposition"]) != nil)) {
        coder = [EDEntityFieldCoder decoderWithFieldBody:fBody];
        contentDisposition = [[coder value] retain];
        contentDispositionParameters = [[coder parameters] retain];
    }
    return contentDisposition;
}


- (NSDictionary *)contentDispositionParameters
{
    [self contentDisposition];
    return contentDispositionParameters;
}


//---------------------------------------------------------------------------------------
//	CONTENT TRANSFER ENCODING
//---------------------------------------------------------------------------------------

- (void) setContentTransferEncoding: (NSString*) anEncoding
{
    [self setBody:anEncoding forHeaderField: @"Content-Transfer-Encoding"];
}


- (NSString*) contentTransferEncoding
{
    return [[[[EDTextFieldCoder decoderWithFieldBody:[self bodyForHeaderField: @"content-transfer-encoding"]] text] stringByRemovingSurroundingWhitespace] lowercaseString];
}


//---------------------------------------------------------------------------------------
//	CONTENT DATA ACCESSOR METHODS
//---------------------------------------------------------------------------------------

- (void) setContentData: (NSData*) data
{
    [self _forgetOriginalTransferData];
		
	if (data != contentData) {
		[contentData release];
		contentData = [data copy];
	}
}


- (NSData*) contentData
{
    if ((contentData == nil) && (originalTransferData != nil)) {
       [self _takeContentDataFromOriginalTransferData];
	}
    return contentData;
}
    

//---------------------------------------------------------------------------------------
//	DERIVED ATTRIBUTES
//---------------------------------------------------------------------------------------

- (NSString*) pathExtensionForContentType
{	
    NSString* extension = [NSString pathExtensionForContentType: [self contentType]];
    if(extension == nil) {
        NSString* subtype = [[[self contentType] componentsSeparatedByString: @"/"] lastObject];
        if([subtype hasPrefix: @"x-"]) subtype = [subtype substringFromIndex:2];
        extension = subtype;
    }
    return extension;
}



//----------------------------------------------------------------------------
//	DESCRIPTION
//----------------------------------------------------------------------------

- (NSString*) description
{
    return [NSString stringWithFormat: @"<%@ 0x%x: %@>", NSStringFromClass(isa), self, [self bodyForHeaderField:@"content-type"]];
}


//---------------------------------------------------------------------------------------
//	INTERNAL STUFF
//---------------------------------------------------------------------------------------

+ (NSDictionary *)_defaultFallbackHeaders
{
    static NSDictionary	*defaultFallbackHeaders = nil;

    if(defaultFallbackHeaders == nil) {
        NSMutableDictionary* temp;
        NSDictionary* parameters;
        NSString* fBody;
        
        temp = [NSMutableDictionary dictionary];
        parameters = [NSDictionary dictionaryWithObject: MIMEAsciiStringEncoding forKey: @"charset"];
        fBody = [[EDEntityFieldCoder encoderWithValue: @"text/plain"
                                        andParameters: parameters] fieldBody];
        [temp setObject: fBody forKey: @"content-type"];
        [temp setObject: MIME8BitContentTransferEncoding forKey: @"content-transfer-encoding"];
        fBody = [[EDEntityFieldCoder encoderWithValue: MIMEInlineContentDisposition andParameters: nil] fieldBody];
        [temp setObject: fBody forKey: @"content-disposition"];
        defaultFallbackHeaders = [[NSDictionary alloc] initWithDictionary: temp];
    }

    return defaultFallbackHeaders;
}


/*" Parses the header fields and returns the NSRange belonging to the message body (for seperate processing). */
- (NSRange)takeHeadersFromData:(NSData *)data
{
    const char		 *p, *pmax, *fnamePtr, *fbodyPtr, *eolPtr;
    NSMutableData	 *fbodyData;
    NSString 		 *name, *fbodyContents;
    NSStringEncoding     encoding = NSISOLatin1StringEncoding;
    
    name = nil;
    fnamePtr = p = [data bytes];
    pmax = p + [data length];
    fbodyPtr = NULL;
    fbodyData = nil;
	
    //NSLog(@"Decoding headers of message:\n%s", p);
	
    for(;p < pmax; p++)
	{
        if((*p == COLON) && (fbodyPtr == NULL))
		{
            fbodyPtr = p + 1;
            if((fbodyPtr < pmax) && (iswhitespace(*fbodyPtr)))
                fbodyPtr += 1;
            name = [NSString stringWithCString:fnamePtr length:(p - fnamePtr)];
		}
        else if(iscrlf(*p))
		{
            eolPtr = p;
            p = skipnewline(p, pmax);
            
            // Ignore header fields without body; which shouldn't exist...
            if(fbodyPtr == NULL)
                continue;
            
            if((p < pmax) && iswhitespace(*p)) // folded header!
			{
                if(fbodyData == nil)
                    fbodyData = [NSMutableData dataWithBytes:fbodyPtr length:(eolPtr - fbodyPtr)];
                else
                    [fbodyData appendBytes:fbodyPtr length:(eolPtr - fbodyPtr)];
                fbodyPtr = p;
			}
            else
			{
                if(fbodyData == nil)
                    fbodyData = (id)[NSData dataWithBytes:fbodyPtr length:(eolPtr - fbodyPtr)];
                else
                    [fbodyData appendBytes:fbodyPtr length:(eolPtr - fbodyPtr)];
                fbodyContents = [NSString stringWithData:fbodyData encoding:encoding];
                // we know something about the implementation of addToHeaderFields ;-)
                // by uniqueing the string here we avoid creating another pair.
                name = [name sharedInstance];
				//field = [[OPObjectPair allocWithZone:[self zone]] initWithObjects:name: fbodyContents];
				
				// making sure not to replace already set fields:
				if (![self bodyForHeaderField:name])
				{
					[self addToHeaderFieldsName:name body:fbodyContents];
				}
				
                fbodyData = nil;
                fnamePtr = p;
                fbodyPtr = NULL;
                if((p < pmax) && iscrlf(*p))
                    break;
			}
		}
	}
		
    p = skipnewline(p, pmax);
    if(p > pmax)
		return NSMakeRange(-1, 0);
	
    return NSMakeRange(p - (char *)[data bytes], pmax - p);
}


- (void) _takeContentDataFromOriginalTransferData
{
    NSString 	*cte;
    NSData		*rawData;

    if(originalTransferData == nil)
        [NSException raise:NSInternalInconsistencyException format: @"-[%@ %@]: Original transfer data not available anymore.", NSStringFromClass(isa), NSStringFromSelector(_cmd)];

    // If we have a contentData already, it must have been created from the original before
    if(contentData != nil)
        return;

    cte = [self contentTransferEncoding];
    rawData = [originalTransferData subdataWithRange:bodyRange];
    contentData = [[rawData decodeContentWithTransferEncoding:cte] retain];
}

- (BOOL) transferDataDidChange 
    /*" Returns YES, if the transferData had been changed since this object was initialized. "*/
{
    return originalTransferData==nil;
}


- (void) _forgetOriginalTransferData
{
    if (originalTransferData == nil) return;

    if(bodyRange.length > 0)
        [self _takeContentDataFromOriginalTransferData];

    [originalTransferData release];
    originalTransferData = nil;
}

//---------------------------------------------------------------------------------------
    @end
//---------------------------------------------------------------------------------------


