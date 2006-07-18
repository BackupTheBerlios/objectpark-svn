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
#import "OPContentCoderCenter.h"
#import "NSString+MessageUtils.h"
#import "OPMultimediaContentCoder.h"
#import "OPApplefileContentCoder.h"
#import "OPAppleDoubleContentCoder.h"
#import "OPMultipartContentCoder.h"
#import "OPXFolderContentCoder.h"
#import "EDPLainTextContentCoder.h"
#import "utilities.h"
#import "EDTextContentCoder.h" // can be removed

#import <OPDebug/OPLog.h>

#define MESSAGEDEBUG  OPL_DOMAIN  @"MESSAGEDEBUG"


@interface EDMessagePart(PrivateAPI)
+ (NSDictionary *)_defaultFallbackHeaders;
- (NSData*) takeHeadersFromData: (NSData*) data;
@end

/*
@implementation EDMessagePart (TemporaryBugFix)

// bufix: made robust for unknown content transfer encodings -> fallback to 7bit
- (id)initWithTransferData: (NSData*) data fallbackHeaderFields:(NSDictionary *)fields
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
    cte = [[(EDTextFieldCoder *)[EDTextFieldCoder decoderWithFieldBody:[self bodyForHeaderField: @"content-transfer-encoding"]] text] stringByRemovingSurroundingWhitespace];
    
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
- (NSString*) contentDisposition
{
    NSString 			*fBody;
    EDEntityFieldCoder	*coder;

    if((contentDisposition == nil) && ((fBody = [self bodyForHeaderField: @"content-disposition"]) != nil))
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
- (NSData*) takeHeadersFromData: (NSData*) data
{
    const char		 *p, *pmax, *fnamePtr, *fbodyPtr, *eolPtr;
    NSMutableData	 *fbodyData;
    NSString 		 *name, *fbodyContents;
    OPObjectPair	 *field;
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
                    field = [[OPObjectPair allocWithZone:[self zone]] initWithObjects:name: fbodyContents];
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
- (NSData*) transferData
{
    NSMutableData	 		*transferData;
    NSData					*headerData;
    NSMutableString			*stringBuffer;
    NSEnumerator			*fieldEnum;
    OPObjectPair			*field;


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
        [headerLine appendString: @": "];
        [headerLine appendString:[field secondObject]];
        [headerLine appendString: @"\r\n"];

        [stringBuffer appendString:[headerLine stringByFoldingStringToLimit:998]];

        [headerLine release];
        }
    [stringBuffer appendString: @"\r\n"];
    
    if (! [stringBuffer canBeConvertedToEncoding:NSASCIIStringEncoding])
    {
        OPDebugLog(MESSAGEDEBUG, OPWARNING, @"-[%@ %@]: Transfer representation of header fields contains non ASCII characters. Fallback to lossy conversion.", NSStringFromClass(isa), NSStringFromSelector(_cmd));
    }
        
    if((headerData = [stringBuffer dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion: YES]) == nil)
    {
        [NSException raise:NSInternalInconsistencyException format: @"-[%@ %@]: Error converting header data to ASCII encoding (despite of use of lossy conversion).", NSStringFromClass(isa), NSStringFromSelector(_cmd)];
    }
    
    [transferData appendData:headerData];

    [transferData appendData:[contentData encodeContentWithTransferEncoding: [self contentTransferEncoding]]];
    
    return transferData;
}
*/

@end

@implementation EDMessagePart (OPExtensions)

+ (NSArray *)preferredContentTypes
/*" Forwards preferredContentTypes to NSApp delegate. Returns a default array of content type strings as default. "*/
{
    static id defaultTypes = nil;
    if ([[NSApp delegate] respondsToSelector:@selector(preferredContentTypes)]) 
    {
        return [[NSApp delegate] preferredContentTypes];
    }
    
    if (!defaultTypes) 
    {
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

- (NSAttributedString*) contentAsAttributedString
{
    return [self contentWithPreferredContentTypes: nil attributed: YES];
}

- (id)contentWithPreferredContentTypes:(NSArray *)preferredContentTypes attributed:(BOOL)shouldBeAttributed
/*" Returns the receivers content as a user presentable attributed string. Returns nil if not decodable. "*/
{
    id content = nil;
    Class contentCoderClass;
    
    contentCoderClass = [self contentDecoderClass];
    
    //if (NSDebugEnabled) NSLog(@"Using DecoderClass = %@", contentCoderClass);
    
    if (contentCoderClass != nil) // found a content coder willing to decode self
    {
        EDContentCoder *contentCoder = [[contentCoderClass alloc] initWithMessagePart:self];
        
        @try 
        {
            if ([contentCoder respondsToSelector:@selector(contentWithPreferredContentTypes:attributed:)]) 
            {
                content = [(id)contentCoder contentWithPreferredContentTypes:preferredContentTypes attributed:shouldBeAttributed];
            } 
            else 
            {
                content = (shouldBeAttributed ? (id)[contentCoder attributedString] : (id)[contentCoder string]);
            }
        } 
        @catch (id localException) 
        {
            OPDebugLog(MESSAGEDEBUG, OPERROR, @"[%@ %@] Exception while extracting contents as attributed string. (%@)", [self class], NSStringFromSelector(_cmd), [localException reason]);
            content = @"Exception while extracting contents as attributed string.";
            if (shouldBeAttributed) content = [[[NSAttributedString alloc] initWithString:content] autorelease];
        } 
        
//#warning debug only
//        [contentCoder autorelease];
        [contentCoder release];
    }
    
    if (! content) 
    {
        content = [NSString stringWithFormat:@"--- Content of type %@ could not be decoded. Falling back to text/plain: ---\n\n", [self contentType]];
        
        if (shouldBeAttributed) content = [[[NSMutableAttributedString alloc] initWithString:content] autorelease];
        
        // Fake text/plain for the content coder to work:
        [self setContentType:@"text/plain" withParameters:[NSDictionary dictionary]];

        EDContentCoder *contentCoder = [[EDPlainTextContentCoder alloc] initWithMessagePart:self];

        @try 
        {
            if (shouldBeAttributed) [content appendAttributedString:[contentCoder attributedString]];
            else content = [content stringByAppendingString:[contentCoder string]]; 
        } 
        @catch (id localException) 
        {
            OPDebugLog(MESSAGEDEBUG, OPERROR, @"[%@ %@] Exception while extracting contents as attributed string. (%@)", [self class], NSStringFromSelector(_cmd), [localException reason]);
            content = @"Exception while extracting contents as attributed string.";
            
            if (shouldBeAttributed) content = [[NSAttributedString alloc] initWithString:content];
        }

        [contentCoder release];
    }
    
    return [[content retain] autorelease];
}

- (NSString *)contentAsPlainString
/*" Returns the contents as a plain text string. Rich content is described as plain text. Suitable for fulltext indexing of the body content (not including the header texts). "*/
{
    return [self contentWithPreferredContentTypes:nil attributed:NO];
}

@end


#import <GPGME/GPGME.h>
#import "EDEntityFieldCoder.h"

@implementation EDMessagePart (OpenPGP)

- (BOOL)isSigned
/*" Returns YES if the receiver has "multipart/signed" content type. NO otherwise. "*/
{
	return [[self contentType] isEqualToString:@"multipart/signed"];
}

- (NSArray *)signatures
/*" Returns the signatures if the receiver has the content type "multipart/signed".
Check the signatures' status for details (e.g. if a signature is good or bad) "*/
{
	if (! [self isSigned]) return nil;
	
	GPGContext *context = nil;
	NSArray *result = nil;
	
	@try
	{
		context = [[GPGContext alloc] init];
		EDCompositeContentCoder *coder = [[[EDCompositeContentCoder alloc] initWithMessagePart:self] autorelease];
		
		NSArray *subparts = [coder subparts];
		NSAssert1([subparts count] == 2, @"Found %d subparts instead of 2.", [subparts count]);
		
		NSData *signatureContentData = [(EDMessagePart *)[subparts objectAtIndex:1] transferData];
		GPGData *signatureData = [[[GPGData alloc] initWithDataNoCopy:signatureContentData] autorelease];
			
		NSData *inputContentData = [(EDMessagePart *)[subparts objectAtIndex:0] transferData];
		//NSData *inputContentData = [NSData dataWithBytes:"asbsfd" length:3];
		GPGData *inputData = [[[GPGData alloc] initWithDataNoCopy:inputContentData] autorelease];

		[context setUsesArmor:YES];
        [context setUsesTextMode:YES];

		result = [context verifySignatureData:signatureData againstData:inputData]; // Can raise an exception
	}
	@catch (id localException)
	{
		NSLog(@"Exception while retrieving signatures: %@", localException);
		return nil;
	}
	@finally
	{
		[context release];
	}
		
	return result;
}

- (NSString *)signatureDescription
/*" Returns a user presentable description of the signature. "*/
{
	NSArray *signatures = [self signatures];
	GPGSignature *signature = [signatures lastObject];
	
	EDEntityFieldCoder *coder = (EDEntityFieldCoder *)[self decoderForHeaderField:@"content-type"];
	NSAssert(coder, @"no content-type coder");
				
	NSString *protocol = [[coder parameters] objectForKey:@"protocol"];
								
	if (! protocol) protocol = @"<unknown>";
	
	NSString *signatureDescription = [NSLocalizedString(@"Invalid Signature", @"Signature description") stringByAppendingFormat:@" - protocol: %@", protocol];
	
	if ([signatures count] == 1)
	{				
		GPGContext *context;
		GPGKey *key = nil;
		
		@try
		{
			context = [[GPGContext alloc] init];
			key = [context keyFromFingerprint:[signature fingerprint] secretKey:NO];
		}
		@catch (id localException)
		{
			NSLog(@"Exception while retrieving key: %@", localException);
		}
		@finally
		{
			[context release];
		}
		
		signatureDescription = GPGErrorDescription([signature status]);

		if ([signatureDescription isEqualToString:@"Success"]) signatureDescription = @"Valid";
		
		NSString *fromAddress = [[[self bodyForHeaderField:@"from"] addressFromEMailString] lowercaseString];
		
		NSString *userIds = nil;
		NSString *trust = [key ownerTrustDescription];
		
		// show only the user id with the from email address if that can be found...:
		if (fromAddress)
		{
			NSEnumerator *enumerator = [[key userIDs] objectEnumerator];
			GPGUserID *userID;
			while (userID = [enumerator nextObject])
			{
				NSString *emailAddress = [[userID email] lowercaseString];
				if ([emailAddress isEqualToString:fromAddress])
				{
					//userIds = [userID description];
					break;
				}
			}
		}
		else
		{
			// ...otherwise list them all:
			userIds = [[key userIDs] componentsJoinedByString:@", "];
		}
		
		if (userIds)
		{
			signatureDescription = [signatureDescription stringByAppendingFormat:@" (%@)", userIds];
		}
		
		if (trust)
		{
			signatureDescription = [signatureDescription stringByAppendingFormat:@", trust: %@", trust];
		}
		
	}	
		
	return signatureDescription;
}

@end
