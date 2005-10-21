/* 
     $Id: OPContentCoderCenter.h,v 1.1 2004/12/23 16:45:16 theisen Exp $

     Copyright (c) 2001 by Bjoern Bubbat. All rights reserved.

     Permission to use, copy, modify and distribute this software and its documentation
     is hereby granted, provided that both the copyright notice and this permission
     notice appear in all copies of the software, derivative works or modified versions,
     and any portions thereof, and that both notices appear in supporting documentation,
     and that credit is given to Bjoern Bubbat in all documents and publicity
     pertaining to direct or indirect use of this code or its derivatives.

     THIS IS EXPERIMENTAL SOFTWARE AND IT IS KNOWN TO HAVE BUGS, SOME OF WHICH MAY HAVE
     SERIOUS CONSEQUENCES. THE COPYRIGHT HOLDER ALLOWS FREE USE OF THIS SOFTWARE IN ITS
     "AS IS" CONDITION. THE COPYRIGHT HOLDER DISCLAIMS ANY LIABILITY OF ANY KIND FOR ANY
     DAMAGES WHATSOEVER RESULTING DIRECTLY OR INDIRECTLY FROM THE USE OF THIS SOFTWARE
     OR OF ANY DERIVATIVE WORK.
*/

#import <Foundation/Foundation.h>

@class EDMessagePart;

@interface OPContentCoderCenter : NSObject {
    @private
    NSMutableArray *_contentCoder; /*" private variable "*/
}

+(OPContentCoderCenter *)contentCoderCenter;
+(Class)contentDecoderClass: (EDMessagePart*) mpart;
+(Class)contentEncoderClassForAttributedString: (NSAttributedString*) anAttributedString atIndex:(int)anIndex effectiveRange:(NSRangePointer)effectiveRange;
+(void)registerContentCoder:(Class)coderClass;

- (void) registerContentCoder:(Class)coderClass;
- (Class)contentDecoderClass: (EDMessagePart*) mpart;
- (Class)contentEncoderClassForAttributedString: (NSAttributedString*) anAttributedString atIndex:(int)anIndex effectiveRange:(NSRangePointer)effectiveRange;


@end
