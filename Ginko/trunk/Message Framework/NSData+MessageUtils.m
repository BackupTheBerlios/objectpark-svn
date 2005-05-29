//---------------------------------------------------------------------------------------
//  NSData+MIME.m created by erik on Sun 12-Jan-1997
//  @(#)$Id: NSData+MIME.m,v 1.2 2005/04/02 12:27:57 theisen Exp $
//
//  Copyright (c) 1997-2000 by Erik Doernenburg. All rights reserved.
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
#import "NSData+Extensions.h"
#import "utilities.h"
#import "NSCharacterSet+MIME.h"
#import "NSString+MessageUtils.h"
#import "NSData+MessageUtils.h"

@interface NSData(EDMIMEExtensionsPrivateAPI)
- (NSData *)_encodeQuotedPrintableStep1;
- (NSData *)_encodeQuotedPrintableStep2;
@end


NSString *MIME7BitContentTransferEncoding = @"7bit";
NSString *MIME8BitContentTransferEncoding = @"8bit";
NSString *MIMEBinaryContentTransferEncoding = @"binary";
NSString *MIMEQuotedPrintableContentTransferEncoding = @"quoted-printable";
NSString *MIMEBase64ContentTransferEncoding = @"base64";


static char* basishex = "0123456789ABCDEF";

static unsigned char indexhex[128] = {
    99,99,99,99, 99,99,99,99, 99,99,99,99, 99,99,99,99,
    99,99,99,99, 99,99,99,99, 99,99,99,99, 99,99,99,99,
    99,99,99,99, 99,99,99,99, 99,99,99,99, 99,99,99,99,
     0, 1, 2, 3,  4, 5, 6, 7,  8, 9,99,99, 99,99,99,99,
    99,10,11,12, 13,14,15,99, 99,99,99,99, 99,99,99,99,
    99,99,99,99, 99,99,99,99, 99,99,99,99, 99,99,99,99,
    99,10,11,12, 13,14,15,99, 99,99,99,99, 99,99,99,99,
    99,99,99,99, 99,99,99,99, 99,99,99,99, 99,99,99,99
};

static __inline__ void encode2bytehex(unsigned int value, char *buffer)
{
    buffer[0] = basishex[value/16];
    buffer[1] = basishex[value%16];
}


static __inline__ unsigned int decode2bytehex(const char *p)
{
    return indexhex[(int)*p] * 16 + indexhex[(int)*(p+1)];
}


static __inline__ BOOL isqpliteral(unsigned char b)
{
    return ((b >= 33) && (b <= 60)) || ((b >=62) && (b <= 126));
}

@implementation NSData(MessageUtils)

- (BOOL)isValidTransferEncoding:(NSString *)encodingName
/*" Returns YES if encoding name describes an encoding scheme that is known to the framework. NO otherwise. "*/
{
    encodingName = [encodingName lowercaseString];
    if([encodingName isEqualToString:MIME7BitContentTransferEncoding])
        return YES;
    if([encodingName isEqualToString:MIME8BitContentTransferEncoding])
        return YES;
    if([encodingName isEqualToString:MIMEBinaryContentTransferEncoding])
        return YES;
    if([encodingName isEqualToString:MIMEQuotedPrintableContentTransferEncoding])
        return YES;
    if([encodingName isEqualToString:MIMEBase64ContentTransferEncoding])
        return YES;
    
    return NO;
}

- (NSData *)decodeContentWithTransferEncoding:(NSString *)encodingName
{
    encodingName = [encodingName lowercaseString];
    if([encodingName isEqualToString:MIME7BitContentTransferEncoding])
        return self;
    if([encodingName isEqualToString:MIME8BitContentTransferEncoding])
        return self;
    if([encodingName isEqualToString:MIMEBinaryContentTransferEncoding])
        return self;
    if([encodingName isEqualToString:MIMEQuotedPrintableContentTransferEncoding])
        return [self decodeQuotedPrintable];
    if([encodingName isEqualToString:MIMEBase64ContentTransferEncoding])
        return [self decodeBase64];
    // If we don't know it, fall back to 7-bit
    return self; 
}

- (NSData *)encodeContentWithTransferEncoding:(NSString *)encodingName
{
    encodingName = [encodingName lowercaseString];
    if([encodingName isEqualToString:MIME7BitContentTransferEncoding])
        return self;
    if([encodingName isEqualToString:MIME8BitContentTransferEncoding])
        return self;
    if([encodingName isEqualToString:MIMEBinaryContentTransferEncoding])
        return self;
    if([encodingName isEqualToString:MIMEQuotedPrintableContentTransferEncoding])
        return [self encodeQuotedPrintable];
    if([encodingName isEqualToString:MIMEBase64ContentTransferEncoding])
        return [self encodeBase64];
    [NSException raise:NSInvalidArgumentException format:@"-[%@ %@]: Unknown content transfer encoding; found '%@'", NSStringFromClass(isa), NSStringFromSelector(_cmd), encodingName];
    return nil; // keep compiler happy
}


//---------------------------------------------------------------------------------------
//	QUOTED PRINTABLE (RFC 2045)
//---------------------------------------------------------------------------------------

- (NSData *)decodeQuotedPrintable
{
    NSMutableData 	*decodedData;
    const char      *source, *endOfSource;
    char           	*dest;

    source = [self bytes];
    endOfSource = source + [self length];
    decodedData = [NSMutableData dataWithLength:[self length]];
    dest = [decodedData mutableBytes];

    while(source < endOfSource)
        {
        if(*source == EQUALS)
            {
            source += 1;
            if(iscrlf(*source) || iswhitespace(*source))
                {
                while(iswhitespace(*source))
                    source += 1;
                if(*source == CR)       // this is not exactly according
                    source += 1;        // to rfc2045 but it does decode
                if(*source == LF)       // it properly while offering
                    source += 1;        // some robustness...
                }
            else
                {
                if(isxdigit(*source) && isxdigit(*(source+1)))
                    {
                    *dest++ = decode2bytehex(source);
                    source += 2;
                    }
                }
            }
        else
            {
            *dest ++ = *source++;
            }
        }
    [decodedData setLength:(unsigned int)((void *)dest - [decodedData mutableBytes])];

    return decodedData;
}


- (NSData *)encodeQuotedPrintable
{
    // this is a bit lame but doing it in one pass proved to be too mind-boggling
    return [[self _encodeQuotedPrintableStep1] _encodeQuotedPrintableStep2];
}


- (NSData *)_encodeQuotedPrintableStep1
{
    NSMutableData	*dest;
    NSData			*chunk;
    char			escBuffer[3] = "=00";
    const unsigned char		*source, *chunkStart, *endOfSource;
    unsigned char			c;

    dest = [[[NSMutableData allocWithZone:[self zone]] init] autorelease];
    source = [self bytes];
    endOfSource = source + [self length];
    while(source < endOfSource)
        {
        c = *source;
        if(iscrlf(c))
            {
            source = (const unsigned char*)skipnewline((const char*)source, (const char*)endOfSource);
            [dest appendBytes:&"\r\n" length:2];
            }
        else if(iswhitespace(c))
            {
            chunkStart = source;
            do
                source += 1;
            while((source < endOfSource) && (iswhitespace(*source) == YES));

            if((source == endOfSource) || iscrlf(*source))
                {
                // need to escape last space.
                chunk = [NSData dataWithBytes:chunkStart length:(source - chunkStart - 1)];
                [dest appendData:chunk];
                encode2bytehex(*(source  - 1), &escBuffer[1]);
                [dest appendBytes:escBuffer length:3];
                }
            else
                {
                // we have a valid continuation char
                chunk = [NSData dataWithBytes:chunkStart length:(source - chunkStart)];
                [dest appendData:chunk];
                }
            }
        else if(isqpliteral(c))
            {
            chunkStart = source;
            do
                source += 1;
            while((source < endOfSource) && isqpliteral(*source));
            chunk = [NSData dataWithBytes:chunkStart length:(source - chunkStart)];
            [dest appendData:chunk];
            }
        else
            {
            source += 1;
            encode2bytehex(c, &escBuffer[1]);
            [dest appendBytes:escBuffer length:3];
            }
        }

    return dest;
}


- (NSData *)_encodeQuotedPrintableStep2
{
    NSMutableData	*dest;
    NSData			*chunk;
    const unsigned char		*source, *chunkStart, *startOfSource, *endOfSource, *softbreakPos;
    int				lineLength;

    dest = [[[NSMutableData allocWithZone:[self zone]] init] autorelease];
    startOfSource = source = [self bytes];
    endOfSource = source + [self length];
    chunkStart = source;
    lineLength = 0;
    while(source < endOfSource)
        {
        if(lineLength < 75)
            {
            if(*source == CR)
                {
                lineLength = 0;
                source += 2;
                }
            else
                {
                lineLength += 1;
                source += 1;
                }
            }
        if(lineLength >= 75)
            {
            softbreakPos = source - 1;
            while(iswhitespace(*softbreakPos) == NO)
                {
                softbreakPos -= 1;
                if((*softbreakPos == LF) || (softbreakPos < startOfSource) || (softbreakPos <= chunkStart))
                    {
                    // couldn't find a space! break anywhere but in the middle of an =XX
                    softbreakPos = source - 1;
                    if(*softbreakPos == EQUALS)
                        softbreakPos -= 1;
                    else if(*(softbreakPos - 1) == EQUALS)
                        softbreakPos -= 2;
                    break;
                    }
                }
            // note: softbreakPos now points to the last char that should be on the line
            softbreakPos += 1;
            chunk = [NSData dataWithBytes:chunkStart length:(softbreakPos - chunkStart)];
            [dest appendData:chunk];
            [dest appendBytes:&"=\r\n" length:3];
            chunkStart = softbreakPos;
            lineLength = (source - softbreakPos);
            }
        }
    if(chunkStart != source)
        {
        chunk = [NSData dataWithBytes:chunkStart length:(source - chunkStart)];
        [dest appendData:chunk];
        }
    return dest;    
}

//---------------------------------------------------------------------------------------
//	QUOTED PRINTABLE FOR HEADERS (RFC ????)
//---------------------------------------------------------------------------------------

- (NSData *)decodeHeaderQuotedPrintable
{
    NSMutableData 	*decodedData;
    const unsigned char      *source, *endOfSource;
    unsigned char            *dest;

    source = [self bytes];
    endOfSource = source + [self length];
    decodedData = [NSMutableData dataWithLength:[self length]];
    dest = [decodedData mutableBytes];

    while(source < endOfSource)
        {
        unsigned char c = *source++;
        if((c == EQUALS) && (source < endOfSource - 1) && isxdigit(*(source)) && isxdigit(*(source+1)))
            {
            c = decode2bytehex((char*)source);
            source += 2;
            }
        else if(c == UNDERSCORE)
            {
            c = SPACE;
            }
        *dest++ = c;
        }
    [decodedData setLength:(unsigned int)((void *)dest - [decodedData mutableBytes])];

    return decodedData;
}

- (NSData *)encodeHeaderQuotedPrintable
{
    return [self encodeHeaderQuotedPrintableMustEscapeCharactersInString:nil];
}

- (NSData *)encodeHeaderQuotedPrintableMustEscapeCharactersInString:(NSString *)escChars
{
    NSMutableCharacterSet *tempCharacterSet;
    NSCharacterSet		  *literalChars;
    NSMutableData		  *buffer;
    unsigned int		  length;
    const unsigned char		   	  *source, *chunkStart, *endOfSource;
    char				  escValue[3] = "=00", underscore = '_';
    
    if(escChars != nil)
    {
        tempCharacterSet = [[NSCharacterSet MIMEHeaderDefaultLiteralCharacterSet] mutableCopy];
        [tempCharacterSet removeCharactersInString:escChars];
        literalChars = [[tempCharacterSet copy] autorelease];
        [tempCharacterSet release];
    }
    else
    {
        literalChars = [NSCharacterSet MIMEHeaderDefaultLiteralCharacterSet];
    }
    
    length = [self length];
    buffer = [[[NSMutableData alloc] initWithCapacity:length + length / 10] autorelease];
    
    chunkStart = source = [self bytes];
    endOfSource = source + length;
    while(source < endOfSource)
    {
        if([literalChars characterIsMember:(unichar)(*source)] == NO)
        {
            if((length = (source - chunkStart)) > 0)
                [buffer appendBytes:chunkStart length:length];
            if(*source == SPACE)
            {
                [buffer appendBytes:&underscore length:1];
            }
            else
            {
                encode2bytehex(*source, &escValue[1]);
                [buffer appendBytes:escValue length:3];
            }
            chunkStart = source + 1;
        }
        source += 1;
    }
    [buffer appendBytes:chunkStart length:(source - chunkStart)];
    
    return buffer;
}

void doFrom_Quoting(NSMutableString* aString) 
/*" From_ quoting for generating mbox data. "*/
{
    NSRange range;
    unsigned length = [aString length];
    
    range.location = 0;
    range.length = length;
    
    do
    {
        range = [aString rangeOfString:@"From " options:NSLiteralSearch range:range];
        if(range.location != NSNotFound)
        {
            unsigned int position;
            
            position = range.location - 1;
            
            while(position >= 0)
            {
                unichar character;
                
                character = [aString characterAtIndex:position];
                if(character == '\n') {
                    // insert quote >
                    [aString insertString:@">" atIndex:position+1];
                    length++;
                    break;
                }
                else if(character != '>')
                {
                    break;
                }
                position--;
            }
            
            range.location += 5; // + From_
            range.length = length - range.location;
        }
    }
    while((range.location != NSNotFound) && (range.location < length));
    
    return;
}

- (NSData *)transferDataFromMboxData
{
    char *start, *end, *pos, *lfPos;
    char *buffer, *copyPos;
    BOOL headerSeen = NO;
    
    unsigned length = [self length];
    
    if (length == 0) return nil;
    
    start = pos = (char *)[self bytes];
    
    // strip trailing blank line
    if (length >= 2)
    {
        if (start[length-1] == '\n')
        {
            --length;
            if (start[length-1] == '\r') --length;
        }
    }
    
    end = start + length;
    
    // alloc buffer
    if (! (copyPos = buffer = malloc((end - pos) * 2 + 4)))  // times 2 to ensures the buffer will be large enough (this will be enough even if the mail contains only 'lf's)
        return nil;
    
    // remove From_ line (if it exists)
    if ((length >= 5) && (!strncmp(pos, "From ", 5)))
    {
        pos += 5;
        while (lfPos = memchr(pos, '\n', end - pos))
        {
            pos = lfPos + 1;
            
            if (pos >= end)
                break;
            if (!isblank(*pos))
                break;
        }
    }
    else *copyPos++ = *pos++;  // copy the first char, even if it's an 'lf' :-/ (this simplifies the code by allowing 'look back by one')
    
    // first line is not >From unquoted (should be OK since >From should only occur in the message body)
    while ((pos < end) && (lfPos = memchr(pos, '\n', end - pos)))
    {
        // copy line and convert 'lf' to 'crlf' if necessary
        if (lfPos[-1] == '\r')   // 'look back by one'
        {
            int lineLength = lfPos+1 - pos;
            memcpy(copyPos, pos, lineLength);
            copyPos += lineLength;
            headerSeen |= (lineLength == 2);
        }
        else
        {
            int lineLength = lfPos - pos;
            memcpy(copyPos, pos, lineLength);
            copyPos += lineLength;
            *copyPos++ = '\r';
            *copyPos++ = '\n';
            headerSeen |= (lineLength == 0);
        }
        pos = lfPos+1;
        
        
        if (pos >= end)
            break;  // end of data reached
        
        
        // search for >From and unquote
        if (*pos == '>')
        {
            char* tempPos = pos;
            while (++tempPos <= (end - 5))
            {
                if (*tempPos == '>')
                    continue;
                
                if (!strncmp(tempPos, "From ", 5))
                    pos++;  // remove the first '>'
                
                break;
            }
        }
    }
    
    // copy the remaining part
    if (pos < end)
    {
        memcpy(copyPos, pos, end - pos);
        copyPos += end - pos;
    }
    
    // check if header ending \r\n\r\n is present -> fixing if needed to avoid crash of EDMessagePart
    if (!headerSeen)
    {
        *copyPos++ = '\r';
        *copyPos++ = '\n';
        *copyPos++ = '\r';
        *copyPos++ = '\n';
    }
    
    NSData *result =  [[[NSData alloc] initWithBytes:buffer length:copyPos - buffer] autorelease];
    
    free(buffer);
    
    return result;
}

- (NSData *)mboxDataFromTransferDataWithEnvSender:(NSString *)envsender
{
    NSMutableData *mboxData;
    NSMutableString *fromQuoteBuffer;
    NSString *from_, *myDate, *fromQuoted;
    NSAutoreleasePool *pool;
    time_t myTime;
    struct tm *ptm;
    char *timestr;
    
    myTime = time(NULL);
    ptm = gmtime (&myTime);
    timestr = asctime(ptm);
    
    pool = [[NSAutoreleasePool alloc] init];
    
    myDate = [NSString stringWithCString:timestr length:24];
    
    if(!envsender) {
        envsender = @"MAILER-DAEMON";
    }
    
    from_ = [NSString stringWithFormat:@"From %@ %@\n", envsender, myDate];
    fromQuoteBuffer = [NSMutableString stringWithCString:[self bytes] length:[self length]];
    
    doFrom_Quoting(fromQuoteBuffer);

    /*
    if (![fromQuoteBuffer hasSuffix:@"\n"])
    {
        [fromQuoteBuffer appendString:@"\n"];
    }
    */
    
    // ensure trailing blank line (e.g. procmail style):
    [fromQuoteBuffer appendString: [fromQuoteBuffer hasSuffix:@"\n"] ? @"\n" : @"\n\n"];
    
    fromQuoted = [fromQuoteBuffer stringWithUnixLinebreaks];
    
    mboxData = [NSMutableData dataWithCapacity:[from_ length] + [fromQuoted length]];
    
    [mboxData appendBytes:[from_ lossyCString] length:[from_ length]];
    [mboxData appendBytes:[fromQuoted lossyCString] length:[fromQuoted length]];
    
    [mboxData retain]; // keep it longer than the pool
    [pool release];
    [mboxData autorelease];
    
    return mboxData;
}

@end

#if 0
static void appendchars(NSMutableString *buffer, const char *p, unsigned int l)
{
    NSString *s = [[NSString alloc] initWithData:[NSData dataWithBytes:p length:l] encoding:NSISOLatin1StringEncoding];
    [buffer appendString:s];
    [s release];
}
#endif
