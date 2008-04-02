//---------------------------------------------------------------------------------------
//  OPInternetMessage.h created by erik on Mon 20-Jan-1997
//  @(#)$Id: OPInternetMessage.h,v 1.2 2005/01/29 21:07:31 mikesch Exp $
//
//  Base Code Copyright (c) 1999 by Erik Doernenburg. All rights reserved.
//  Extensions Copyright (c) 2004 by Dirk Theisen. All rights reserved.
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

#import "EDMessagePart.h"

extern NSString *EDMessageTypeException;
extern NSString *EDMessageFormatException;

typedef enum
{
	OPMessagePartTypeFull,
	OPMessagePartTypePart
} OPMessagePartType;

@interface OPInternetMessage : EDMessagePart
{
}

- (BOOL)isEqualToMessage:(OPInternetMessage *)other;

+ (id)messageWithAttributedStringContent:(NSAttributedString *)someContent type:(OPMessagePartType)messagePartType;

- (void)zapHeaderGremlins;
- (NSString *)generatedMessageIdWithSuffix:(NSString *)aString;

- (NSData *)transferData;
- (NSString *)messageId;
- (void) setMessageId: (NSString*) value;

// The message ids of the messages the message refer to.
- (NSArray *)references;

- (NSString *)replyToWithFallback:(BOOL)fallback;
- (NSString *)toWithFallback:(BOOL)fallback;
- (NSString *)fromWithFallback:(BOOL)fallback;
- (NSString *)ccWithFallback:(BOOL)fallback;
- (NSString *)bccWithFallback:(BOOL)fallback;

- (NSString *)allRecipientsWithFallback:(BOOL)fallback;

- (NSString *)normalizedSubject;

@end
