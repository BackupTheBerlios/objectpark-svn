//---------------------------------------------------------------------------------------
//  EDCompositeContentCoder.m created by erik on Sun 18-Apr-1999
//  @(#)$Id: EDCompositeContentCoder.m,v 1.3 2005/03/26 02:29:44 theisen Exp $
//
//  Copyright (c) 1997-1999 by Erik Doernenburg. All rights reserved.
//  Copyright (c) 2004 by Dirk Theisen. All rights reserved.
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
#import "OPInternetMessage.h"
#import "EDEntityFieldCoder.h"
#import "EDCompositeContentCoder.h"
#import "utilities.h"

@interface EDCompositeContentCoder(PrivateAPI)
- (void)_takeSubpartsFromMultipartContent:(EDMessagePart *)mpart;
- (void)_takeSubpartsFromMessageContent:(EDMessagePart *)mpart;
- (id)_encodeSubpartsWithClass:(Class)targetClass subtype:(NSString *)subtype;
@end


//---------------------------------------------------------------------------------------
    @implementation EDCompositeContentCoder
//---------------------------------------------------------------------------------------

static short boundaryId = 0;


//---------------------------------------------------------------------------------------
//	CAPABILITIES
//---------------------------------------------------------------------------------------

+ (BOOL)canDecodeMessagePart:(EDMessagePart *)mpart
{
    if ([[mpart contentType] hasPrefix:@"multipart/"]) return YES;
    if ([[mpart contentType] isEqualToString: @"message/rfc822"]) return YES;
    if ([[mpart contentType] isEqualToString: @"message/rfc2822"]) return YES;
    return NO;
}


//---------------------------------------------------------------------------------------
//	INIT & DEALLOC
//---------------------------------------------------------------------------------------

- (id)initWithMessagePart:(EDMessagePart *)mpart
{
    if (self = [self init]) 
	{
        if ([[mpart contentType] hasPrefix:@"multipart/"]) 
		{
			[self _takeSubpartsFromMultipartContent:mpart];
        } 
		else if ([[mpart contentType] isEqualToString:@"message/rfc822"] 
				 || [[mpart contentType] isEqualToString:@"message/rfc2822"]) 
		{
            [self _takeSubpartsFromMessageContent:mpart];
        } 
		else 
		{
            // need [self dealloc] here?
            //[NSException raise:NSInvalidArgumentException format: @"%@: Invalid content type %@", NSStringFromClass([self class]), [mpart bodyForHeaderField:@"content-type"]];
            NSLog(@"%@: Invalid content type %@", NSStringFromClass([self class]), [mpart bodyForHeaderField:@"content-type"]);
            [self dealloc];
            return nil;
        }	
    }
    return self;
}

- (id) initWithSubparts: (NSArray*) someParts
{
    if (self = [self init]) {
        subparts = [someParts retain];
    }
    return self;
}

- (void) dealloc
{
    [subparts release]; subparts = nil;
    [super dealloc];
}


//---------------------------------------------------------------------------------------
//	ATTRIBUTES
//---------------------------------------------------------------------------------------

- (NSArray*) subparts
{
    return subparts;
}


- (EDMessagePart*) messagePart
{
    return [self _encodeSubpartsWithClass: [EDMessagePart class] subtype: @"mixed"];
}

- (EDMessagePart *)messagePartWithSubtype: (NSString*) subtype
{
    return [self _encodeSubpartsWithClass: [EDMessagePart class] subtype: subtype];
}


- (OPInternetMessage*) message
{
    return [self _encodeSubpartsWithClass: [OPInternetMessage class] subtype: @"mixed"];
}

- (OPInternetMessage*) messageWithSubtype: (NSString*) subtype
{
    return [self _encodeSubpartsWithClass: [OPInternetMessage class] subtype: subtype];
}


//---------------------------------------------------------------------------------------
//	CODING
//---------------------------------------------------------------------------------------

- (void)_takeSubpartsFromMultipartContent:(EDMessagePart *)mpart
{
    NSDictionary *defaultHeadersFields;
    EDEntityFieldCoder *fcoder;
    NSString *charset;
	NSString *boundary;
    const char *btext, *startPtr, *possibleEndPtr, *p, *pmin, *pmax, *q;
    unsigned int blen;
    NSRange	subpartRange;
    EDMessagePart *subpart;
    BOOL done = NO;
	
    if ((boundary = [[mpart contentTypeParameters] objectForKey: @"boundary"]) == nil)
        [NSException raise:EDMessageFormatException format: @"no boundary for multipart"];
    btext = [boundary cString];
    blen = strlen(btext);
    if ([[mpart contentType] hasSuffix: @"/digest"]) {
        fcoder = [EDEntityFieldCoder encoderWithValue: @"message/rfc822" andParameters: nil];
        defaultHeadersFields = [NSDictionary dictionaryWithObject: [fcoder fieldBody] forKey: @"content-type"];
    } else {
        charset = [NSString MIMEEncodingForStringEncoding:NSASCIIStringEncoding];
        fcoder = [EDEntityFieldCoder encoderWithValue: @"text/plain" andParameters: [NSDictionary dictionaryWithObject: charset forKey: @"charset"]];
        defaultHeadersFields = [NSDictionary dictionaryWithObject:[fcoder fieldBody] forKey: @"content-type"];
	}
	
    subparts = [[[NSMutableArray allocWithZone:[self zone]] init] autorelease]; // autoreleased for the case that an exception has to be thrown
	
    pmin = p = [[mpart contentData] bytes];
    pmax = p + [[mpart contentData] length];
    startPtr = possibleEndPtr = NULL;
    while(done == NO)
	{  // p == 0 can occur if part was empty, ie. had no body
//        if((p == 0) || (p > pmax - 5 - blen)) // --boundary--\n
		if((p == 0) || (p > pmax - 4 - blen)) // --boundary--
            [NSException raise: EDMessageFormatException format: @"final boundary not found"];
        if((*p == '-') && (*(p+1) == '-') && (strncmp(p+2, btext, blen) == 0))
		{
            q = p + 2 + blen;
            if((*q == '-') && (*(q+1) == '-'))
			{
                done = YES;
                q += 2;
			}
            if((q = skipspace(q, pmax)) == NULL)  // might have been added
                [NSException raise: EDMessageFormatException format: @"final boundary not found"];
            if(iscrlf(*q) == NO)
			{
                NSLog(@"Warning: ignoring junk after mime multipart boundary '%@'.", boundary);
                if((q = skiptonewline(q, pmax)) == NULL)
                    [NSException raise:EDMessageFormatException format: @"final boundary not found"];
			}
			
            if(startPtr != NULL)
			{
                subpartRange.location = startPtr - (const char *)[[mpart contentData] bytes];
                subpartRange.length = possibleEndPtr - startPtr;
                subpart = [[[EDMessagePart allocWithZone:[self zone]] initWithTransferData:[[mpart contentData] subdataWithRange:subpartRange] fallbackHeaderFields:defaultHeadersFields] autorelease];
                [subparts addObject:subpart];
			}
            startPtr = p = skipnewline(q, pmax); // trailing crlf belongs to boundary
		}
        else
		{
            if((p = skiptonewline(p, pmax)) == NULL)
                [NSException raise:EDMessageFormatException format: @"final boundary not found"];
            possibleEndPtr = p;
            p = skipnewline(p, pmax);
		}
	}
	
	[subparts retain]; // no exception had to be thrown...keep the subparts
}


- (void) _takeSubpartsFromMessageContent: (EDMessagePart*) mpart
{
    OPInternetMessage	*msg;

    msg = [[OPInternetMessage allocWithZone:[self zone]] initWithTransferData:[mpart contentData]];
    subparts = [[NSArray allocWithZone:[self zone]] initWithObjects:msg, nil];
    [msg release];
}


- (id)_encodeSubpartsWithClass: (Class) targetClass subtype: (NSString*) subtype
{
    EDMessagePart		*result, *subpart;
    NSString			*boundary, *cte, *rootPartType;
    NSMutableDictionary	*ctpDictionary;
    NSEnumerator		*subpartEnum;
    NSData			*boundaryData, *linebreakData;
    NSMutableData		*contentData;
    
    result = [[[targetClass alloc] init] autorelease];
    
    // Is it okay to use a time stamp? (Conveys information which might not be known otherwise...) 
    boundary = [NSString stringWithFormat: @"EDMessagePart-%ld%d", (long)[NSDate timeIntervalSinceReferenceDate] + 978307200, boundaryId];  // 978307200 is the difference between unix and foundation reference dates 
    boundaryId = (boundaryId + 1) % 10000;
    ctpDictionary = [NSMutableDictionary dictionary];
    [ctpDictionary setObject: boundary forKey: @"boundary"];
    if ([[subtype lowercaseString] isEqualToString: @"related"]) {
        rootPartType = [[subparts objectAtIndex:0] contentType];
        [ctpDictionary setObject: rootPartType forKey: @"type"];
    }
    [result setContentType: [@"multipart/" stringByAppendingString: subtype] 
            withParameters: ctpDictionary];
    boundaryData = [[@"--" stringByAppendingString:boundary] dataUsingEncoding:NSASCIIStringEncoding];
    linebreakData = [@"\r\n" dataUsingEncoding:NSASCIIStringEncoding];
    
    cte = MIME7BitContentTransferEncoding;
    contentData = [NSMutableData data];
    [contentData appendData:[@"This is a MIME encoded message.\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    subpartEnum = [subparts objectEnumerator];
    while((subpart = [subpartEnum nextObject]) != nil)
    {
        if([[subpart contentTransferEncoding] isEqualToString:MIME8BitContentTransferEncoding])
            cte = MIME8BitContentTransferEncoding;
        [contentData appendData: linebreakData];
        [contentData appendData: boundaryData];
        [contentData appendData: linebreakData];
        [contentData appendData: [subpart transferData]];
    }
    [contentData appendData: linebreakData];
    [contentData appendData: boundaryData];
    [contentData appendData: [@"--\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [result setContentData: contentData];
    [result setContentTransferEncoding: cte];
    
    return result;
}


//---------------------------------------------------------------------------------------
    @end
//---------------------------------------------------------------------------------------
