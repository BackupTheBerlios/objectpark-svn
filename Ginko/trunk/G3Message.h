//
//  G3Message.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 01.12.04.
//  Copyright 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "OPManagedObject.h"

@class OPInternetMessage;
@class G3Thread;

#define OPSeenStatus 1
#define OPAnsweredStatus 2
#define OPFlaggedStatus 4
#define OPDeletedStatus 8
#define OPDraftStatus 16
#define OPRecentStatus 32
#define OPQueuedStatus 64
#define OPExpungedStatus 128
#define OPUninterestingStatus 256
#define OPSendingBlockedStatus 512
#define OPPublicMessageStatus 1024
#define OPQueuedSendNowStatus 2048
#define OPInSendJobStatus 4096
#define OPJunkMailStatus 8192
#define OPIsFromMeStatus 16384

@interface G3Message : NSManagedObject 
{
}

+ (id)messageForMessageId:(NSString *)messageId;
+ (id)messageWithTransferData:(NSData *)someTransferData;

- (NSData *)transferData;

- (NSString *)messageId;
- (G3Message *)reference;
- (G3Message *)referenceFind:(BOOL)find;

- (unsigned)numberOfReferences;

- (unsigned)flags;
- (void)setFlags:(unsigned)someFlags;
- (BOOL)hasFlag:(unsigned)flag;
- (void)addFlags:(unsigned)someFlags;
- (void)removeFlags:(unsigned)someFlags;

- (NSAttributedString *)contentAsAttributedString;

- (G3Thread *)thread;
- (G3Thread *)threadCreate:(BOOL)doCreate;

- (NSArray *)commentsInThread:(G3Thread *)thread;

- (BOOL)isDummy;
- (BOOL)isSeen;
- (void)setSeen:(BOOL)isSeen;

/*" Fulltext Indexing Support "*/
- (BOOL)isFulltextIndexed;
- (void)setIsFulltextIndexed:(BOOL)value;

- (BOOL)isListMessage;
- (BOOL)isUsenetMessage;
- (BOOL)isEMailMessage;
- (BOOL)isPublicMessage;

- (BOOL)isFromMe;

- (NSString *)senderName;

- (OPInternetMessage *)internetMessage;

- (void)putInSendJobStatus;
- (void)removeInSendJobStatus;

@end

/*" Raised when trying to create a dupe message. userInfo holds the dupe transfer data for the key transferData. "*/
extern NSString *GIDupeMessageException;
