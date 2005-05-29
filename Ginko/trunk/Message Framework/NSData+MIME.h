//---------------------------------------------------------------------------------------
//  NSData+MIME.h created by erik on Sun 12-Jan-1997
//  @(#)$Id: NSData+MIME.h,v 1.1 2004/12/23 16:45:16 theisen Exp $
//
//  Copyright (c) 1997-1999 by Erik Doernenburg. All rights reserved.
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

#import "OPInternetMessage.h"


@interface NSData (EDMIMEExtensions)


- (BOOL)isValidTransferEncoding:(NSString *)encodingName;

- (NSData *)decodeContentWithTransferEncoding:(NSString *)encodingName;
- (NSData *)encodeContentWithTransferEncoding:(NSString *)encodingName;

- (NSData *)decodeQuotedPrintable;
- (NSData *)encodeQuotedPrintable;

- (NSData *)decodeHeaderQuotedPrintable;
- (NSData *)encodeHeaderQuotedPrintable;
- (NSData *)encodeHeaderQuotedPrintableMustEscapeCharactersInString:(NSString *)escChars;

- (NSData *)mboxDataFromTransferDataWithEnvSender:(NSString *)envsender;
- (NSData *)transferDataFromMboxData;

@end

extern NSString *MIME7BitContentTransferEncoding;
extern NSString *MIME8BitContentTransferEncoding;
extern NSString *MIMEBinaryContentTransferEncoding;
extern NSString *MIMEQuotedPrintableContentTransferEncoding;
extern NSString *MIMEBase64ContentTransferEncoding;

