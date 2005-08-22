//
//  GIMessage.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 22.07.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OPPersistence.h"

@class GIThread;
@class GIProfile;
@class OPInternetMessage;

#define OPSeenStatus 1
#define OPAnsweredStatus 2
#define OPFlaggedStatus 4
//#define OPDeletedStatus 8
#define OPDraftStatus 16
//#define OPRecentStatus 32
#define OPQueuedStatus 64
//#define OPExpungedStatus 128
#define OPInterestingStatus 256
#define OPSendingBlockedStatus 512
//#define OPPublicMessageStatus 1024
#define OPFulltextIndexedStatus 2048
#define OPInSendJobStatus 4096
#define OPJunkMailStatus 8192
#define OPIsFromMeStatus 16384

@interface GIMessage : OPPersistentObject {
    int flagsCache; // should move to attributes dictionary so it does not put load onto the faults?
}

+ (id) messageForMessageId: (NSString*) messageId;
+ (id) messageWithTransferData: (NSData*) someTransferData;

- (NSData*) transferData;

- (NSString*) messageId;
- (GIMessage*) reference;
- (GIMessage*) referenceFind: (BOOL)find;

- (unsigned) numberOfReferences;

- (unsigned) flags;
- (BOOL) hasFlags: (unsigned) someFlags;
- (void) addFlags: (unsigned) someFlags;
- (void) removeFlags: (unsigned) someFlags;

- (NSString*) flagsString; // use only for export
- (void) addFlagsFromString: (NSString*) flagsString; // use only for import

- (NSAttributedString*) contentAsAttributedString;

- (GIThread*) thread;
- (GIThread*) threadCreate: (BOOL) doCreate;

- (NSArray*) commentsInThread: (GIThread*) thread;

- (BOOL) isListMessage;
- (BOOL) isUsenetMessage;
- (BOOL) isEMailMessage;
- (BOOL) isPublicMessage;
- (BOOL) isDummy;

- (NSString*) senderName;

- (void) flushInternetMessageCache;
- (OPInternetMessage*) internetMessage;

- (void) setSendJobStatus;
- (void) resetSendJobStatus;

@end

@interface GIMessageData : OPPersistentObject {
}
 
@end
