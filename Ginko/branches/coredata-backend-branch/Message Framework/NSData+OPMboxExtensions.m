/* 
     NSData+OPMboxExtensions.m created by axel on Wed 27-Dec-2000
     $Id: NSData+OPMboxExtensions.m,v 1.1 2005/01/17 00:00:59 theisen Exp $

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

#import "NSData+OPMboxExtensions.h"
#import <stdio.h>

@implementation NSData (MboxExtensions)

- (id)initWithContentsOfFileHandle:(FILE *)file range:(NSRange)range
{
    void *bytes;

    if (fseek(file, range.location, SEEK_SET) != 0)
    {
        [self autorelease];
        [NSException raise:NSRangeException format:@"The range's location is behind end of the file."];
    }

    bytes = malloc(range.length);

    if (! bytes)
    {
        [self autorelease];
        [NSException raise:NSMallocException format:@"Could not alloc memory for range."];
    }

    if (fread(bytes, 1, range.length, file) < range.length)
    {
        int filelength;

        fseek(file, 0, SEEK_END);
        filelength = ftell(file);

        free(bytes);
        [self autorelease];
        [NSException raise:NSRangeException format:[NSString stringWithFormat:@"A part of the range is behind end of the file (range.location=%d, range.length=%d, file length=%d).", range.location, range.length, filelength]];
    }
    
    return [self initWithBytesNoCopy:bytes length:range.length freeWhenDone:YES];
}

- (id)initWithContentsOfFile:(NSString *)path range:(NSRange)range
/*" Creates and returns a data object by reading bytes from the file specified by path in the specified range. Raises, if the file couldn't be opened or the range is out of bounds. "*/
{
    FILE *file;
    const char *fileName;
    
    fileName = [path fileSystemRepresentation];

    file = fopen(fileName, "r");

    if (! file)
    {
        [self autorelease];
        [NSException raise:NSObjectInaccessibleException format:@"Could not open the file for reading."];
    }

    NS_DURING
        self = [self initWithContentsOfFileHandle:file range:range];
    NS_HANDLER
        fclose(file);
        [localException raise];
    NS_ENDHANDLER

    fclose(file);
        
    return self;
}

- (NSData *)mboxSubdataFromOffset:(unsigned)offset endOffset:(unsigned *)endOffset
{
    unsigned length;
    const void *bytes, *pos, *maxpos;
    static const char newline = '\n';
    static const char *from =  "From ";
    
    length = [self length];
    bytes = [self bytes];
    pos = bytes + offset;
    maxpos = bytes + length;
    *endOffset = 0;

    // check if From_ is in the beginning
    if(memcmp(pos, from, 5))
        return nil;

    pos += 5;

    while( (*endOffset == 0) && (pos <= maxpos) )
    {
        pos = memchr(pos, newline, (maxpos - pos));

        if(pos == NULL)
            *endOffset = length - 1;
        else if(!memcmp(from, pos + 1, 5))
            *endOffset = pos - bytes;
        
        pos += 1;
    }

    if(*endOffset == 0)
        return nil;

//    MPWDebugLog(@"->%@<-", [NSString stringWithCString:bytes + offset length:*endOffset - offset]);
    return [NSData dataWithBytes:bytes + offset length:*endOffset - offset];
}

@end
