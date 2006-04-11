//---------------------------------------------------------------------------------------
//  NSString+MessageUtils.h created by erik on Sun 23-Mar-1997
//  @(#)$Id: NSString+MessageUtils.h,v 1.8 2005/03/25 11:19:13 mikesch Exp $
//
//  Copyright (c) 1997-2000 by Erik Doernenburg. All rights reserved.
//  Copyright (c) 2004 by Axel Katerbau & Dirk Theisen. All rights reserved.
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
#import "NSString+Extensions.h"

// key for object of class NSNumber (interpreted as int) -> quotation level
extern NSString *OPQuotationAttributeName;
extern NSString *OPQuotationPrefixAttributeName;

extern NSString *OPAttachmentPathAttribute;

@interface NSString (OPMessageUtilities) 

- (BOOL)isValidMessageID;
- (NSString*) getURLFromArticleID;

- (NSString*) stringByRemovingBracketComments;

- (NSString*) realnameFromEMailString;
- (NSString*) addressFromEMailString;
- (NSArray*) addressListFromEMailString;

- (NSString*) stringByRemovingReplyPrefix;

- (NSString*) stringByApplyingROT13;

- (NSString*) stringByUnwrappingParagraphs;
- (NSString*) stringByWrappingToLineLength:(unsigned int)length;
- (NSString*) stringByPrefixingLinesWithString: (NSString*) prefix;
//- (NSString*) stringByFoldingStringToLimit:(int)limit;
//- (NSString*) stringByUnfoldingString;


- (NSString*) stringByFoldingToLimit:(unsigned int)limit;
- (NSString*) stringByUnfoldingString;

- (NSString*) realnameFromEMailStringWithFallback; // falls back to self if no realname is found.

+ (NSString*) temporaryFilename;
+ (NSString*) xUnixModeString:(int)aNumber;

- (NSAttributedString *)attributedStringWithQuotationAttributes;
- (long)octalValue;

- (NSCalendarDate *)dateFromRFC2822String;
//- (NSCalendarDate *)slowDateFromRFC2822String;

- (NSString*) stringByNormalizingWhitespaces;

- (NSArray*) fieldListFromEMailString;
// - (NSArray*) realnameListFromEMailString;

- (NSString*) stringByEncodingFlowedFormat;
- (NSString*) stringByWrappingToSoftLimit: (unsigned int) length;

- (NSString*) stringBySpaceStuffing;
- (NSString*) stringByDecodingFlowedUsingDelSp:(BOOL)useDelSp;
- (NSString*) stringByEncodingFlowedFormat;

- (NSString*) stringByStrippingTrailingWhitespacesAndNewlines;
- (long)longValue;
- (NSString*) stringByRemovingAttachmentChars;

@end


@interface NSMutableString (OPMessageUtilities)

- (void) appendAsLine: (NSString*) line withPrefix: (NSString*) prefix;

@end

@interface NSString (OPPunycode)

- (NSString*) punycodeDecodedString;
- (NSString*) punycodeEncodedString;

- (NSString*) IDNADecodedDomainName;
- (NSString*) IDNAEncodedDomainName;

@end
