/* 
     NSData+OPMboxExtensions.h created by axel on Wed 27-Dec-2000
     $Id: NSData+OPMboxExtensions.h,v 1.1 2005/01/17 00:00:59 theisen Exp $

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

#import <Foundation/Foundation.h>

@interface NSData (MboxExtensions)

- (id)initWithContentsOfFile:(NSString *)path range:(NSRange)range;
- (id)initWithContentsOfFileHandle:(FILE *)file range:(NSRange)range;

- (NSData *)mboxSubdataFromOffset:(unsigned)offset endOffset:(unsigned *)endOffset;

@end
