/* 
     EDMessagePart+OPMboxExtensions.m created by axel on Wed 27-Dec-2000
     $Id: EDMessagePart+OPMboxExtensions.m,v 1.2 2005/01/17 07:42:38 theisen Exp $

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

#import "EDMessagePart+OPMboxExtensions.h"
#import "NSString+MessageUtils.h"
#import "MPWDebug.h"

@interface EDMessagePart (MboxExtensionsPrivateAPI)
- (void)_from_QuoteString:(NSMutableString *)aString;
@end


/* cf. mbox man entry (qmail) for specs */
@implementation EDMessagePart (MboxExtensions)


- (id) initWithMboxData: (NSData*) data
{
    char *start, *end, *pos, *lfPos;
    char *buffer, *copyPos;
    BOOL headerSeen = NO;
    
    unsigned length = [data length];
    start = pos = (char*)[data bytes];
    
    // strip trailing blank line
    if (length >= 2)
        if (start[length-1] == '\n')
            {
            --length;
            
            if (start[length-1] == '\r')
                --length;
            }
        
    end = start + length;
    
    // alloc buffer
    if (! (copyPos = buffer = malloc((end - pos) * 2 +4)))  // times 2 to ensures the buffer will be large enough (this will be enough even if the mail contains only 'lf's)
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
    else
        *copyPos++ = *pos++;  // copy the first char, even if it's an 'lf' :-/ (this simplifies the code by allowing 'look back by one')
        
        
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
    
    // do the initialization
    NSData* transferData = [[NSData allocWithZone:[self zone]] initWithBytes:buffer length:copyPos - buffer];
    self = [self initWithTransferData:transferData];
    [transferData release];
    
    free(buffer);
    
    return self;
}


- (NSData*) mboxData
{
    NSData *transferData;
    NSMutableData *mboxData;
    NSMutableString *fromQuoteBuffer;
    NSString *from_, *myDate, *envsender, *fromQuoted;
    NSAutoreleasePool *pool;
    time_t myTime;
    struct tm *ptm;
    char *timestr;

    myTime = time(NULL);
    ptm = gmtime (&myTime);
    timestr = asctime(ptm);

    pool = [[NSAutoreleasePool alloc] init];
    
    transferData = [self transferData];

    myDate = [NSString stringWithCString:timestr length:24];
    NS_DURING
        envsender = [[self bodyForHeaderField:@"from"] addressFromEMailString];
    NS_HANDLER
        NSLog(@"Broken email address!");
        envsender = nil;
    NS_ENDHANDLER
    
    if(!envsender)
    {
        envsender = @"MAILER-DAEMON";
    }

    from_ = [NSString stringWithFormat:@"From %@ %@\n", envsender, myDate];
    fromQuoteBuffer = [NSMutableString stringWithCString:[transferData bytes] length:[transferData length]];
    [self _from_QuoteString:fromQuoteBuffer];
    if([fromQuoteBuffer hasSuffix:@"\n"])
    {
        [fromQuoteBuffer appendString:@"\n"];
    }
    else
    {
        [fromQuoteBuffer appendString:@"\n\n"];
    }

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

@implementation EDMessagePart (MboxExtensionsPrivateAPI)

- (void)_from_QuoteString:(NSMutableString *)aString
{
    NSRange range;
    unsigned length;

    length = [aString length];

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

@end



