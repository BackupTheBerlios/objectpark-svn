//---------------------------------------------------------------------------------------
//  OPInternetMessage.m created by erik on Mon 20-Jan-1997
//  @(#)$Id: OPInternetMessage.m,v 1.3 2005/04/07 17:16:53 theisen Exp $
//
//  Base Copyright (c) 1999-2000 by Erik Doernenburg. All rights reserved.
//  Extensions Copyright (c) 2004 by Dirk Theisen. All rights reserved.
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
#import "NSString+Extensions.h"
#import "NSString+MessageUtils.h"
#import "EDTextFieldCoder.h"
#import "EDIdListFieldCoder.h"
#import "OPInternetMessage.h"
#import "OPMultimediaContentCoder.h"
#import "OPMultipartContentCoder.h"
#import "OPXFolderContentCoder.h"
//#import "OPContentCoderCenter.h"
#import "NSData+OPMD5.h"
//#import "GIUserDefaultsKeys.h"

NSString *EDMessageTypeException = @"EDMessageTypeException";
NSString *EDMessageFormatException = @"EDMessageFormatException";

//---------------------------------------------------------------------------------------
    @implementation OPInternetMessage
//---------------------------------------------------------------------------------------

//---------------------------------------------------------------------------------------
//	INIT & DEALLOC
//---------------------------------------------------------------------------------------

- (id)initWithTransferData: (NSData*) data fallbackHeaderFields:(NSDictionary *)fields
{
    NSString *version;
    
    [super initWithTransferData:data fallbackHeaderFields:fields];

    // a bit late maybe...
    if(((version = [self bodyForHeaderField: @"mime-version"]) != nil) && ([version length] > 0))
        if([[version stringByRemovingBracketComments] floatValue] > 1.0)
            NSLog(@"Warning: MIME Decoder: decoded version %@ as 1.0.", version);

    return self;
}


//---------------------------------------------------------------------------------------
//	TRANSFER LEVEL ACCESSOR METHODS
//---------------------------------------------------------------------------------------

- (NSData*) transferData
{
    // If we don't have a cached version we'll be constructing the transfer data. In this
    // case tag with our version.
    if((originalTransferData == nil) && ([self bodyForHeaderField: @"mime-version"] == nil))
    {
        NSString *desig = @"Ginko - http://www.objectpark.org";
        [self setBody:[NSString stringWithFormat: @"1.0 (%@)", desig] forHeaderField:@"MIME-Version"];
    }
    return [super transferData];
}



- (NSArray*) references 
/*" Returns an array of messages in the reply-chain, either taken from the
   'References' (prefered) or the 'In-Reply-To' header. "*/
{
    NSArray*            result = nil;
    EDIdListFieldCoder* coder  = nil;
    NSAutoreleasePool*  pool   = [[NSAutoreleasePool alloc] init];
    
    NSString* inReplyTo  = [self bodyForHeaderField: @"in-reply-to"];
    NSString* references = [self bodyForHeaderField: @"references"];
    
    if (references) {
        coder = [[EDIdListFieldCoder alloc] initWithFieldBody:references];
        
        result = [[coder list] retain];
        [coder release];
    }
	else if (inReplyTo) {
        result = [[NSArray arrayWithObject:inReplyTo] retain];
    }
    
    [pool release];
    
    if([result count] == 0) {
        [result release];
        return nil;
    }
    else {
        return [result autorelease];
    }
}

- (NSString *)replyToWithFallback:(BOOL)fallback 
{
    /*"If there is no "replyTo:" header found, this method returns the content of the "from:" header."*/
    NSString *replyBody = nil;
    NSString *listIdBody = nil;
    
    listIdBody = [self bodyForHeaderField:@"list-post"];
    replyBody = [self bodyForHeaderField:@"reply-to"];
    
    // take care of "strange" configured mailing lists, where the Reply-To header is equal to the List-Post header:
    if ([listIdBody isEqualToString:replyBody]) replyBody = [self fromWithFallback:fallback];
    
    // fall back to "from" header:
    if (![replyBody length]) return [self fromWithFallback:fallback];
    
    return [[EDTextFieldCoder stringFromFieldBody:replyBody
                                     withFallback:YES] sharedInstance];
}

- (NSString *)toWithFallback:(BOOL)fallback 
{
    return [[EDTextFieldCoder stringFromFieldBody:[self bodyForHeaderField:@"to"]
                                     withFallback:YES] sharedInstance];
}

- (NSString *)fromWithFallback:(BOOL)fallback 
{
    return [[EDTextFieldCoder stringFromFieldBody:[self bodyForHeaderField:@"from"]
                                     withFallback:YES] sharedInstance];
}

- (NSString *)ccWithFallback:(BOOL)fallback 
{
    return [[EDTextFieldCoder stringFromFieldBody:[self bodyForHeaderField:@"cc"]
                                     withFallback:YES] sharedInstance];
}

- (NSString *)bccWithFallback:(BOOL)fallback 
{
    return [[EDTextFieldCoder stringFromFieldBody:[self bodyForHeaderField:@"bcc"]
                                     withFallback:YES] sharedInstance];
}


- (NSString*) normalizedSubject
    /*" Makes a best effort to generate a nice subject, suitable for display and threading.
    Removes reply-prefixes etc. "*/
{
    NSString* subj;
    NSRange oldSubjRange;
    
    NS_DURING
        subj = [self originalSubject];
        subj = [subj stringByRemovingSurroundingWhitespace];
        if ([subj hasSuffix: @")"])
        {
            // english version
            oldSubjRange = [subj rangeOfString: @"(was:" options:NSLiteralSearch|NSCaseInsensitiveSearch];
            if (oldSubjRange.location == NSNotFound)
                // german version
                oldSubjRange = [subj rangeOfString: @"(war:" options:NSLiteralSearch|NSCaseInsensitiveSearch];
            
            if (oldSubjRange.location != NSNotFound)
                subj = [subj substringToIndex:oldSubjRange.location];
        }
	NS_HANDLER
            subj = [self bodyForHeaderField: @"subject"];
	NS_ENDHANDLER
        
    NSArray *junkPrefixes = [[NSUserDefaults standardUserDefaults] objectForKey:@"JunkReplySubjectPrefixes"];
    
    NSEnumerator *enumerator = [junkPrefixes objectEnumerator];
    NSString *junkPrefix;
    
    while (([subj length] > 0) && (junkPrefix = [enumerator nextObject]) != nil)
    {
        if ([subj hasPrefix:junkPrefix])
        {
            subj = [[subj substringFromIndex:[junkPrefix length]] stringByRemovingSurroundingWhitespace];
            enumerator = [junkPrefixes objectEnumerator]; // start from beginning
        }
    }
    
	return [[[subj stringByRemovingSurroundingWhitespace] stringByNormalizingWhitespaces] sharedInstance];
}


//---------------------------------------------------------------------------------------
//	IS EQUAL
//---------------------------------------------------------------------------------------

- (BOOL)isEqual:(id)other
{
    if((isa != ((OPInternetMessage *)other)->isa) && ([other isKindOfClass:[OPInternetMessage class]] == NO))
        return NO;
    return [[self messageId] isEqualToString:[other messageId]];
}


- (BOOL)isEqualToMessage: (OPInternetMessage*) other
{
    return [[self messageId] isEqualToString:[other messageId]];
}

//---------------------------------------------------------------------------------------
//	CONVENIENCE METHODS FOR ATTACHMENTS
//---------------------------------------------------------------------------------------

// later maybe...

- (void) addAttachment: (NSData*) data withName: (NSString*) name
{
    
}

- (void) addAttachment: (NSData*) data withName: (NSString*) name setInlineFlag:(BOOL)inlineFlag
{
}


+ (id)messageWithAttributedStringContent:(NSAttributedString *)someContent type:(OPMessagePartType)messagePartType
/*" Returns a message with the content corresponding to someContent and the corresponding header fields. 
    However, the message is not complete as vital header fields are missing. They have to be added before
    the message is a valid one. "*/
{
    NSMutableArray *encodersAndRanges;
    NSRange effectiveRange;
    NSAutoreleasePool *pool;
    OPInternetMessage *message = nil;
    unsigned int length;
    
    pool = [[NSAutoreleasePool alloc] init];
    
    // find out which classes can/should encode someContent
    
    encodersAndRanges = [NSMutableArray array];
    
    length = [someContent length];
    effectiveRange = NSMakeRange(0, 0);
    
    while (NSMaxRange(effectiveRange) < length) 
    {
        // try out the encoder candidates
        NSRange localEffectiveRange;
        Class encoderClass;
        
        localEffectiveRange.location = effectiveRange.location;
        localEffectiveRange.length = effectiveRange.length;
        
        encoderClass = [EDContentCoder contentEncoderClassForAttributedString:someContent atIndex:NSMaxRange(localEffectiveRange) effectiveRange:&localEffectiveRange];
        
//        encoderClass = NSClassFromString(@"EDPlainTextContentCoder");
//        localEffectiveRange.length = length;
        
        if (encoderClass != nil)
        {
            effectiveRange.location = localEffectiveRange.location;
            effectiveRange.length = localEffectiveRange.length;
            [encodersAndRanges addObject:[NSArray arrayWithObjects:NSStringFromClass(encoderClass) , NSStringFromRange(effectiveRange), nil]];
        }
        else
        {
            NSLog(@"Warning: No encoder found...leaving out a substring!");
            effectiveRange.location += 1; // skip one character
            effectiveRange.length = (effectiveRange.length > 0) ? effectiveRange.length - 1 : 0;
        }
    }
    
    // if no decoder found return empty message
    if ([encodersAndRanges count] == 0)
    {
		if (messagePartType == OPMessagePartTypeFull)
		{
			return [[[OPInternetMessage alloc] init] autorelease];
		}
		else
		{
			return [[[EDMessagePart alloc] init] autorelease];
		}
    }
    	
    // if one class is sufficient encode with OPInternetMessage as target
    if ([encodersAndRanges count] == 1)
    {
        Class encoderClass;
        NSRange range;
        OPObjectPair *encoderAndRange;
        EDContentCoder *encoder; 
        
        encoderAndRange = [encodersAndRanges lastObject];
        
        encoderClass = NSClassFromString([encoderAndRange objectAtIndex:0]);
        range = NSRangeFromString([encoderAndRange objectAtIndex:1]);
        
        encoder = [[encoderClass alloc] initWithAttributedString:[someContent attributedSubstringFromRange:range]];
        
		if (messagePartType == OPMessagePartTypeFull)
		{		
			message = [[encoder message] retain];
		}
		else
		{
			message = [[encoder messagePart] retain];
		}
        
        [encoder release];
    }
    else // if more than one class is needed then encode with EDMessagePart as target... 
    {
        NSMutableArray *subparts;
        NSEnumerator *enumerator;
        OPObjectPair *encoderAndRange;
        OPMultipartContentCoder *multipartCoder;
        
        subparts = [NSMutableArray array];
        
        enumerator = [encodersAndRanges objectEnumerator];
        while (encoderAndRange = [enumerator nextObject])
        {
            Class encoderClass;
            NSRange range;
            EDContentCoder *encoder = nil; 
            
            encoderClass = NSClassFromString([encoderAndRange objectAtIndex:0]);
            range = NSRangeFromString([encoderAndRange objectAtIndex:1]);
            
            encoder = [[encoderClass alloc] initWithAttributedString:[someContent attributedSubstringFromRange:range]];
            
            NSAssert(encoder != nil, @"Encoder seems to be unwilling to be initialized by initWithAttributedString.");
            
            [subparts addObject:[encoder messagePart]];
            
            [encoder release];
        }
        // ...and encode the parts multipart/mixed with OPInternetMessage as target
        multipartCoder = [[EDCompositeContentCoder alloc] initWithSubparts:subparts];
        
		if (messagePartType == OPMessagePartTypeFull)
		{		
			message = [[multipartCoder message] retain];
		}
		else
		{
			message = [[multipartCoder messagePart] retain];
		}
        
        [multipartCoder release];
    }
    
    [pool release];
		
    return [message autorelease];
}

- (id)initWithTransferData: (NSData*) transferData 
{
    NSParameterAssert(transferData != nil); // Adds this assertion.
    return [super initWithTransferData: transferData];
}

- (NSRange)takeHeadersFromData: (NSData*) data
{
    NSRange result = [super takeHeadersFromData:data];
    
    if (![[self bodyForHeaderField: @"message-id"] length]) 
    {
        [self generateMessageIdWithSuffix: @"FakedByOPMS2@objectpark.org"];
    }
    return result;
}

/*"Returns a NSData containing the complete header as a string."*/
- (NSData*) _headerData
{
    NSEnumerator *fieldEnum;
    OPObjectPair *field;
    NSMutableString *stringBuffer = [[[NSMutableString alloc] init] autorelease];
    
    fieldEnum = [[self headerFields] objectEnumerator];
    while ((field = [fieldEnum nextObject]) != nil) 
    {
        [stringBuffer appendString:[field objectAtIndex:0]];
        [stringBuffer appendString: @": "];
        [stringBuffer appendString:[field objectAtIndex:1]];
        [stringBuffer appendString: @"\r\n"];
    }
    
    return [stringBuffer dataUsingEncoding:NSUTF8StringEncoding];
}

static NSCharacterSet *gremlinCharacterSet()
{
    static NSCharacterSet *_gremlinCharacterSet = nil;
    if (!_gremlinCharacterSet) 
    {
        _gremlinCharacterSet = [[[NSCharacterSet characterSetWithRange:NSMakeRange(0, 128)] invertedSet] retain];
    }
    return _gremlinCharacterSet;
}

- (void) zapHeaderGremlins
/*" Removes non-ascii characters from header bodies. "*/
{
    NSEnumerator *fieldEnum = [[self headerFields] objectEnumerator];
    OPObjectPair *field;    
    while ((field = [fieldEnum nextObject]) != nil) 
    {
        NSString *body = [field objectAtIndex:1];
        //NSLog(@"Checking header '%@' for gremlins: %@", [field firstObject], body);
        if ([body rangeOfCharacterFromSet:gremlinCharacterSet()].length > 0) 
        {
            if (NSDebugEnabled) NSLog(@"Warning: Removing gremlin characters from body for header '%@': %@", [field objectAtIndex:0], body);
            body = [body stringByRemovingCharactersFromSet:gremlinCharacterSet()];
            [self setBody:body forHeaderField:[field objectAtIndex:0]];
        }
    }
}

/*"Generates a message ID string (to use for messages without a message ID)."*/
- (void) generateMessageIdWithSuffix: (NSString*) aString
{
    static NSCharacterSet *equalsSet = nil;
    if (!equalsSet) equalsSet = [[NSCharacterSet characterSetWithCharactersInString: @"="] retain];
    
    NSString *md5sum = [[[self _headerData] md5Base64String] stringByTrimmingCharactersInSet:equalsSet];
    [self setBody:[NSString stringWithFormat: @"<GI%@%@>", md5sum, aString] forHeaderField:@"Message-ID"];
    // Make sure we can generate the transferData:
    [self zapHeaderGremlins]; // we destroyed the original transferData anyway
}

//---------------------------------------------------------------------------------------
    @end
//---------------------------------------------------------------------------------------
