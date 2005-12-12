//---------------------------------------------------------------------------------------
//  NSString+printf.m created by erik on Sat 27-Sep-1997
//  @(#)$Id: NSString+Extensions.h,v 1.3 2004/12/23 16:12:01 mikesch Exp $
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



#import <Foundation/NSString.h>

@class NSFileHandle, OPObjectPair;

/*" Various common extensions to #NSString. "*/

@interface NSString (OPExtensions)

/*" Convenience factory methods "*/
+ (NSString*) stringWithData: (NSData*) data encoding:(NSStringEncoding)encoding;

/*" Handling whitespace "*/
- (NSString*) stringByRemovingSurroundingWhitespace;
- (BOOL)isWhitespace;
- (NSString*) stringByRemovingWhitespace;
- (NSString*) stringByRemovingCharactersFromSet: (NSCharacterSet*) set;

/*" Comparisons "*/
- (BOOL) hasPrefixCaseInsensitive: (NSString*) string;
- (BOOL) isEmpty;

/*" Conversions "*/
- (BOOL) boolValue;
- (unsigned int) intValueForHex;
- (long long) longLongValue;

/*" Using MIME encoding names "*/
+ (NSString*) stringWithData: (NSData*) data 
                MIMEEncoding: (NSString*) charsetName;
+ (NSString*) stringWithBytes: (const void*) buffer 
                       length: (unsigned int) length 
                 MIMEEncoding: (NSString*) charsetName;

- (id)initWithData:(NSData*) buffer MIMEEncoding: (NSString*) charsetName;
- (NSData*) dataUsingMIMEEncoding: (NSString*) charsetName;

+ (NSStringEncoding)stringEncodingForMIMEEncoding: (NSString*) charsetName;
+ (NSString*) MIMEEncodingForStringEncoding:(NSStringEncoding)encoding;
- (NSString*) recommendedMIMEEncoding;

/*" Filename extensions for MIME types "*/
+ (NSString*) pathExtensionForContentType: (NSString*) contentType;
+ (NSString*) contentTypeForPathExtension: (NSString*) extension;
+ (void) addContentTypePathExtensionPair: (OPObjectPair*) tePair;

/*" Determining encoding of XML documents "*/
+ (NSString*) MIMEEncodingOfXMLDocument: (NSData*) xmlData;
+ (NSStringEncoding) encodingOfXMLDocument: (NSData*) xmlData;

#ifndef WIN32
/*" Encryptions "*/
- (NSString*) encryptedString;
- (NSString*) encryptedStringWithSalt: (const char *)salt;
- (BOOL)isValidEncryptionOfString: (NSString*) aString;
#endif

#ifndef EDCOMMON_WOBUILD
/*" Abbreviating paths "*/
- (NSString*) stringByAbbreviatingPathToWidth:(float)maxWidth forFont: (NSFont*) font;
- (NSString*) stringByAbbreviatingPathToWidth:(float)maxWidth forAttributes: (NSDictionary*) attributes;
#endif

/*" Sharing instances "*/
- (NSString*) sharedInstance;

/*" Printing/formatting "*/
+ (void) printf: (NSString*) format, ...;
+ (void) fprintf: (NSFileHandle*) fileHandle: (NSString*) format, ...;
- (void) printf;
- (void) fprintf: (NSFileHandle*) fileHandle;

@end

/*" String constants for common MIME string ecoding names. In Core Foundation these are referred to as IANA charset names. Unless you know a method/framework uses "shared" or "pooled" strings you must compare using #{isEqualToString:} and not the !{==} operator. "*/
extern NSString *MIMEAsciiStringEncoding;
extern NSString *MIMELatin1StringEncoding;
extern NSString *MIMELatin2StringEncoding;
extern NSString *MIME2022JPStringEncoding;
extern NSString *MIMEUTF8StringEncoding;

/*" String constants for common MIME content types. Unless you know a method/framework uses "shared" or "pooled" strings you must compare using #{isEqualToString:} and not !{==}. "*/
extern NSString *MIMEApplicationContentType;
extern NSString *MIMEImageContentType;
extern NSString *MIMEAudioContentType;
extern NSString *MIMEMessageContentType;
extern NSString *MIMEMultipartContentType;
extern NSString *MIMETextContentType;
extern NSString *MIMEVideoContentType;

extern NSString *MIMEAlternativeMPSubtype;
extern NSString *MIMEMixedMPSubtype;
extern NSString *MIMEParallelMPSubtype;
extern NSString *MIMEDigestMPSubtype;
extern NSString *MIMERelatedMPSubtype;

extern NSString *MIMEInlineContentDisposition;
extern NSString *MIMEAttachmentContentDisposition;


/*" Various common extensions to #NSMutableString. "*/

@interface NSMutableString (OPExtensions)

/*" Removing characters "*/
- (void) removeWhitespace;
- (void) removeCharactersInSet: (NSCharacterSet*) set;

@end

@interface NSString (OPColorConverting) 

+ (NSString*) stringFromColor: (NSColor*) color;
- (NSColor*)  colorValue;

@end

extern inline NSString *makeStringIfNil(NSString *str);
