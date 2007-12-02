/* 
     OPInternetMessage+GinkoExtensions.m created by axel on Sat 09-Dec-2000
     $Id: OPInternetMessage+GinkoExtensions.m,v 1.4 2005/03/26 02:29:44 theisen Exp $

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

#import "OPInternetMessage+GinkoExtensions.h"
#import "string.h"
#import "NSString+MessageUtils.h"
#import "NSAttributedString+MessageUtils.h";
#import "NSData+OPMD5.h"
#import "EDMessagePart+OPExtensions.h"
#import "NSAttributedString+Extensions.h"

unsigned int MessageIdCounter = 0;

@implementation OPInternetMessage (GinkoExtensions)

/*
+ (OPInternetMessage *)messagePartForContent:(OPObjectPair *)typeAndContent 
{
    if([typeAndContent firstObject] == nil) 
    {
        // text part
        EDPlainTextContentCoder *coder;
        OPInternetMessage *message;

        // stringWithUnixLinebreaks ensures that all linebreaks are of the same type.
        // This is very important because flowed text encoding can only deal with one type
        // in a given string. axel
        coder = [[EDPlainTextContentCoder allocWithZone:[self zone]] 
                initWithText:[[[typeAndContent secondObject] string] stringWithUnixLinebreaks]];
        [coder setDataMustBe7Bit: YES];
        
        message = [coder message];
        
        [coder release];
        
        return message;
    } else {
        // attachment part
        OPInternetMessage     *messagePart;
        NSFileWrapper *fileWrapper;
        NSString      *filename, *suffix;
        NSData        *data;

        fileWrapper = [[typeAndContent firstObject] fileWrapper];
        filename = [fileWrapper preferredFilename];

        {
            NSArray*components;

            components = [filename componentsSeparatedByString: @"."];
            suffix = [components objectAtIndex:[components count]-1];
        }

        if (NSDebugEnabled) NSLog(@"filename: %@", filename);

        if(![fileWrapper isRegularFile]) {
            return nil;
        }

        data = [fileWrapper regularFileContents];

        if( ([suffix caseInsensitiveCompare:@"tiff"] == NSOrderedSame)
            || ([suffix caseInsensitiveCompare:@"tif"] == NSOrderedSame)
            || ([suffix caseInsensitiveCompare:@"jpeg"] == NSOrderedSame)
            || ([suffix caseInsensitiveCompare:@"jpg"] == NSOrderedSame)
            || ([suffix caseInsensitiveCompare:@"gif"] == NSOrderedSame)
            || ([suffix caseInsensitiveCompare:@"bmp"] == NSOrderedSame)
            ) {
            //      EDHeaderFieldCoder *fieldCoder;

            messagePart = [[OPInternetMessage alloc] init];
            [messagePart setContentData:data];
            [messagePart autorelease];

            // Content-Type
            [messagePart setContentType:[OPObjectPair pairWithObjects:@"image":suffix]
                         withParameters:[NSDictionary dictionaryWithObject:filename forKey:@"name"]];

            // Content-Transfer-Encoding
            [messagePart setContentTransferEncoding:MIMEBase64ContentTransferEncoding];

            // Content-Disposition
            [messagePart setContentDisposition:@"inline"
                                withParameters:[NSDictionary dictionaryWithObject:filename forKey:@"filename"]];

            return messagePart;
        } else {
            //      EDHeaderFieldCoder *fieldCoder;

            messagePart = [[OPInternetMessage alloc] init];
            [messagePart setContentData:data];
            [messagePart autorelease];

            // Content-Type
            [messagePart setContentType:[OPObjectPair pairWithObjects:@"application":@"octet-stream"]
                         withParameters:[NSDictionary dictionaryWithObject:filename forKey:@"name"]];

            // Content-Transfer-Encoding
            [messagePart setContentTransferEncoding:MIMEBase64ContentTransferEncoding];

            // Content-Disposition
            [messagePart setContentDisposition:@"inline"
                                withParameters:[NSDictionary dictionaryWithObject:filename forKey:@"filename"]];

            return messagePart;
        }
    }

    return nil;
}

+ (id)messageWithBodyContent:(NSAttributedString *)contentString {
    NSArray        *partContentStrings;
    NSMutableArray *messageParts;
    unsigned int   i, count;
    partContentStrings = [contentString divideContentStringTypedStrings];
    messageParts = [NSMutableArray array];

    // create message parts for all part content strings
    count = [partContentStrings count];
    for(i=0; i<count; i++) {
        EDMessagePart *part;

        part = [self messagePartForContent:[partContentStrings objectAtIndex:i]];

        if(part != nil) {
            [messageParts addObject:part];
        }
    }

    count = [messageParts count];

    if(count == 0) {
        return nil;
    }

    if(count > 1) {
        // multipart
        NSMutableData        *data;
        OPInternetMessage            *msg;
        NSString             *boundary, *precedingBoundary, *endingBoundary;
//        EDHeaderFieldCoder *fieldCoder;

        // calc boundary

        boundary = [NSString stringWithFormat:@"Ginko-%u", [[messageParts objectAtIndex:0] hash]];
        if (NSDebugEnabled) NSLog(@"boundary = %@", boundary);

        data = [NSMutableData data];

        // write preamble
        {
            NSString *preamble = @"This is a multi-part message in MIME format.\r\n";

            [data appendBytes:[preamble cString] length:[preamble length]];
        }

        // add parts
        precedingBoundary = [NSString stringWithFormat:@"\r\n--%@\r\n", boundary];
        for(i=0; i<count; i++) {
            // preceding boundary
            [data appendBytes:[precedingBoundary cString] length:[precedingBoundary length]];
            [data appendData:[[messageParts objectAtIndex:i] transferData]];
        }

        endingBoundary = [NSString stringWithFormat:@"\r\n--%@--\r\n", boundary];
        [data appendBytes:[endingBoundary cString] length:[endingBoundary length]];

        msg = [[OPInternetMessage alloc] init];
        [msg setContentData:data];
        [msg autorelease];

        // Content-Type
        [msg setContentType:[OPObjectPair pairWithObjects:@"multipart":@"mixed"]
                     withParameters:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"%@", boundary] forKey:@"boundary"]];

        // Content-Transfer-Encoding
        [msg setContentTransferEncoding:MIME7BitContentTransferEncoding];

        return msg;
    } else {
        // single part
        return [messageParts objectAtIndex:0];
    }

    return nil;
}

- (void) dealloc {
//    if (NSDebugEnabled) NSLog(@"RFMessage dealloc");
    [super dealloc];
}
*/

- (NSString*) description 
{
    return [NSString stringWithCString:[[self transferData] bytes] length:[[self transferData] length]];
}

/*
- (BOOL) isUsenetMessage
    /" Returns YES, if Ginko thinks (from the message headers) that this message is an Usenet News article (note, that a message can be both, a usenet article and an email), "/
{
    return ([self bodyForHeaderField:@"Newsgroups"] != nil);
}
*/

/*
- (BOOL) isEMailMessage
    /" Returns YES, if Ginko thinks (from the message headers) that this message is some kind of email (note, that a message can be both, a usenet article and an email). "/
{
    return ([self bodyForHeaderField:@"To"] != nil);
}
*/


/*
- (BOOL) isPublicMessage {
	return [self isListMessage] || [self isUsenetMessage];
}
*/

/*
- (BOOL) isFromMe
	/"
Returns YES, if the from: header contains one of my SMTP addresses configured.
	 "/
{
	// Note that this method operates on the encoded header field. It's OK because email
	// addresses are 7bit only.
	return [[OPMessageAccountManager sharedInstance] doesStringContainMyAddress: [self bodyForHeaderField: @"from"]];
}
*/

- (NSMutableAttributedString*) bodyContent 
{
    NSMutableAttributedString* bodyContent;

    @try 
    {
        bodyContent = [[NSMutableAttributedString alloc] initWithAttributedString:[self contentWithPreferredContentTypes:[EDMessagePart preferredContentTypes] attributed:YES]];
    } 
    @catch (id localException) 
    {
        NSLog(@"warning: [%@]\n", [localException reason]);
        bodyContent = [[NSMutableAttributedString alloc] initWithString: @"Not decodable.\nFallback to text/plain:\n\n"];
        [self setContentType:@"text/plain"];
        [bodyContent appendAttributedString: [self contentAsAttributedString]];
    }

    return [bodyContent autorelease];
}

- (NSAttributedString *)editableBodyContent
/*"Returns message in a format suitable for editing. That means the quoted lines are wrapped to 72 characters."*/
{
    NSMutableAttributedString *result = [[[NSMutableAttributedString alloc] init] autorelease];
    NSMutableAttributedString *bodyContent = [self bodyContent];
    NSArray *partContentStrings = [bodyContent divideContentStringTypedStrings];
    NSEnumerator *enumerator = [partContentStrings objectEnumerator];
	NSArray *typeAndContent;

    while (typeAndContent = [enumerator nextObject])
    {
        if([typeAndContent objectAtIndex:0] == [NSNull null]) 
        {   
			// text part
            // Ginko currently only supports the creation of text/plain messages 
            // so the following line is OK.
            [result appendString:[[typeAndContent objectAtIndex:1] quotedStringWithLineLength:72 byIncreasingQuoteLevelBy:0]];
        } 
        else 
        {
            [result appendAttributedString:[typeAndContent objectAtIndex:1]];
        }
    }
    
    return result;
}

/*
- (void) generateMessageIdWithAccount:(OPMessageAccount *)anAccount
/" Generates an unique message id given the account information anAccount. The message id consists of the fixed string Ginko, an session-unique number, the current time and date and the users email account information. The username will be hashed to hide user info. "/
{
    NSString *email;
    NSCalendarDate *aDate;
    NSMutableString *mid, *stringToHash;
    NSRange range;
    NSString *domain, *username, *timeString, *hash;
    
    email = [anAccount objectForKey:OPAEmail];
    aDate = [self date];

    if(aDate == nil) 
    {
        aDate = [NSCalendarDate date];
    }

    range = [email rangeOfString: @"@"];
    if (range.location != NSNotFound)
    {
        domain = [email substringWithRange:NSMakeRange(range.location, [email length] - range.location)];
        username = [email substringWithRange:NSMakeRange(0, range.location)];
    } else {
        domain = email;
        username = email;
    }

    timeString = [aDate descriptionWithCalendarFormat:@"%y%m%d%H%M%S%z"];
    stringToHash = [NSMutableString stringWithString:timeString];
    [stringToHash appendString:email];
    [stringToHash appendFormat:@"%u", MessageIdCounter++];

    hash = [[stringToHash dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion: YES] md5Base64String];

    while ([hash hasSuffix: @"="])
    {
        hash = [hash substringToIndex:[hash length] - 1];
    }
    
    mid = [NSMutableString stringWithString: @"<"];
    [mid appendString:[aDate descriptionWithCalendarFormat:@"%y%m"]];
    [mid appendString:hash];
    [mid appendString:domain];
    [mid appendString: @">"];

    [self setBody:mid forHeaderField:@"Message-ID"];
}
*/

/*
- (BOOL)isGinkoMessage 
/"YES if the receiver was generated by Ginko. NO otherwise."/
{
    if (! [self isUsenetMessage]) 
    {
        NSString *xmailer;
        
        if (xmailer = [self bodyForHeaderField:@"X-Mailer"]) 
        {
            if ([xmailer rangeOfString: @"Ginko"].location != NSNotFound) 
            {
                return YES;
            }
        }
    } 
    else 
    {
        NSString *useragent;
        
        if (useragent = [self bodyForHeaderField:@"User-Agent"]) 
        {
            if ([useragent rangeOfString: @"Ginko"].location != NSNotFound) 
            {
                return YES;
            }
        }
    }
    return NO;
}
*/

- (BOOL)isMultiHeader:(NSArray *)headerField
{
    BOOL foundOnce = NO;
    NSString *compareString;
    
    compareString = [headerField objectAtIndex:0];
    
	for (NSArray *header in [self headerFields])
	{
        if ([[header objectAtIndex:0] isEqualToString:compareString]) 
		{
            if (foundOnce)
                return YES;
            else
                foundOnce = YES;
        }
    }
    
    return NO;
}


@end