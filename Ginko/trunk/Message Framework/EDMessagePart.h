//---------------------------------------------------------------------------------------
//  EDMessagePart.h created by erik on Mon 20-Jan-1997
//  @(#)$Id: EDMessagePart.h,v 1.3 2005/03/25 23:39:34 theisen Exp $
//
//  Copyright (c) 1999 by Erik Doernenburg. All rights reserved.
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


#import "EDHeaderBearingObject.h"


@interface EDMessagePart : EDHeaderBearingObject
{
    NSDictionary *fallbackFields;
    NSString *contentType;
    NSDictionary *contentTypeParameters;
    NSString *contentDisposition;
    NSDictionary *contentDispositionParameters;
    NSData *contentData;
    NSData *originalTransferData;
    NSRange	bodyRange;
}

- (id)initWithTransferData:(NSData *)data;
- (id)initWithTransferData:(NSData *)data fallbackStringEncoding:(NSStringEncoding)encoding;
- (id)initWithTransferData:(NSData *)data fallbackHeaderFields:(NSDictionary *)fields;

- (NSData *)transferData;
- (BOOL)transferDataDidChange;

- (NSRange)takeHeadersFromData:(NSData *)data;

- (void)setContentType:(NSString *)aType;
- (void)setContentType:(NSString *)aType withParameters:(NSDictionary *)someParameters;
- (NSString *)contentType;
- (NSDictionary *)contentTypeParameters;

- (void)setContentDisposition:(NSString *)aDispositionDirective;
- (void)setContentDisposition:(NSString *)aDispositionDirective withParameters:(NSDictionary *)someParameters;
- (NSString *)contentDisposition;
- (NSDictionary *)contentDispositionParameters;

- (void)setContentTransferEncoding:(NSString *)anEncoding;
- (NSString *)contentTransferEncoding;

- (void)setContentData:(NSData *)data;
- (NSData *)contentData;

- (NSString *)pathExtensionForContentType;

@end

@interface EDMessagePart (OPApplefileExtensions)

- (BOOL)isApplefile;
- (BOOL)isAppleDouble;

@end

