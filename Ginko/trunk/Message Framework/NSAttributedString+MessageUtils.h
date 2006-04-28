/* 
     $Id: NSAttributedString+MessageUtils.h,v 1.8 2005/01/25 19:09:48 mikesch Exp $

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

     Further information can be found on the project's web pages
     at http://www.objectpark.org/Ginko.html
*/

#import <AppKit/AppKit.h>

extern NSString *OPStringFromColor(NSColor *color);
extern NSColor *OPColorFromString(NSString *string);

@interface NSAttributedString (QuotationExtensions)

+ (NSColor *)defaultLinkColor;

- (NSString *)quotedStringWithLineLength:(int)lineLength byIncreasingQuoteLevelBy:(int)levelDelta;
- (NSString *)firstLevelMicrosoftTOFUQuote;

@end


@interface NSMutableAttributedString (QuotationExtensions)

- (void)prepareQuotationsForDisplay;

@end

@interface NSMutableAttributedString (MessageAdditions)

/*" Appending "special" objects "*/
- (void)appendAttachmentWithFileWrapper:(NSFileWrapper *)aFileWrapper showInlineIfPossible:(BOOL)shouldShowInline;
- (void)appendAttachmentWithFileWrapper:(NSFileWrapper *)aFileWrapper;

- (void)appendURL:(NSString *)aURL;
- (void)appendURL:(NSString *)aURL linkColor:(NSColor *)linkColor;
- (void)appendImage:(NSData *)data name:(NSString *)name;

- (NSMutableAttributedString *)urlify;
- (NSMutableAttributedString *)urlifyWithLinkColor:(NSColor *)linkColor;
- (NSMutableAttributedString *)urlifyWithLinkColor:(NSColor *)linkColor range:(NSRange)range;

- (NSArray *)divideContentStringTypedStrings;
- (BOOL)hasRichAttributes;

@end



