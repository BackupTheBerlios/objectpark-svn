//
//  $Id: OPMessageDataEnumerator.m,v 1.1 2005/01/17 00:00:59 theisen Exp $
//  OPMessageServices
//
//  Created by Jšrg Westheide on Mon Jul 19 2004.
//  Copyright (c) 2004 Objectpark Development Group. All rights reserved.
//

#import "OPMessageDataEnumerator.h"
#import "OPMBoxFile.h"


@implementation OPMessageDataEnumerator

+ (id) enumeratorWithMBox: (OPMBoxFile*) theMbox
{
    return [[[self alloc] initWithMBox: theMbox] autorelease];
}

- (id) initWithMBox: (OPMBoxFile*) theMbox
{
        if (self = [super init]) {
            mbox = [theMbox retain];
            offset = 0;
            length = (unsigned) [theMbox mboxFileSize];
        }
        return self;
}

- (unsigned) offsetOfNextObject 
{
    return offset;
}

- (id) nextObject
{

    if (offset >= length) return nil;

    unsigned endOffset;
    NSData *mboxData;
    NSRange range;


    mboxData = [mbox mboxSubdataFromOffset:offset endOffset:&endOffset];

    if (mboxData == nil)
    {
        NSLog(@"Warning: No data for making message... (%u %u) trying at next position (leaving out garbage)", offset, endOffset);
        offset += 1; // trying at next position (leaving out garbage)
        return [NSData data];
    }

    range = NSMakeRange(offset, endOffset - offset + 1);

     
    offset = endOffset + 1;

    return mboxData;
}

- (void) dealloc 
{
    [mbox release];
    [super dealloc];
}

@end
