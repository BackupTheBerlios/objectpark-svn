/* 
     $Id: EDMessagePart+OPExtensions.h,v 1.3 2005/04/19 06:02:47 mikesch Exp $

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

#import "EDMessagePart.h"

@interface EDMessagePart (OPExtensions)

/*" sorted by user preference "*/
+ (NSArray *)preferredContentTypes;

/*" Returns the class capable of decoding the content of self. Returns nil if no decoder class found. "*/
- (Class)contentDecoderClass;

/*" Returns the contents as a user presentable attributed string "*/
- (NSAttributedString *)contentAsAttributedString;
- (id)contentWithPreferredContentTypes:(NSArray *)preferredContentTypes attributed:(BOOL)shouldBeAttributed;

/*" Returns the contents as a plain text string (including metadata information). Use this string for fulltext indexing of the body content. "*/
- (NSString *)contentAsPlainString;

@end

@interface EDMessagePart (OpenPGP)

- (BOOL)isSigned;
- (NSArray *)signatures;
- (NSString *)signatureDescription;

@end

