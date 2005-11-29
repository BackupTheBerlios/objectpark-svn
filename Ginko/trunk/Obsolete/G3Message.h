//
//  GIMessage.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 01.12.04.
//  Copyright 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "OPManagedObject.h"

@class OPInternetMessage;
@class G3Thread;
@class G3Profile;

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

@interface G3Message : NSManagedObject 
{
    int flagsCache;
}

+ (id) messageForMessageId: (NSString*) messageId;
+ (id) messageWithTransferData: (NSData*) someTransferData;

- (NSData*) transferData;

- (NSString*) messageId;
- (G3Message*) reference;
- (G3Message*) referenceFind: (BOOL)find;

- (unsigned) numberOfReferences;

- (unsigned) flags;
- (BOOL) hasFlags: (unsigned) someFlags;
- (void) addFlags: (unsigned) someFlags;
- (void) removeFlags: (unsigned) someFlags;

- (NSString*) flagsString; // use only for export
- (void) addFlagsFromString: (NSString*) flagsString; // use only for import

- (NSAttributedString*) contentAsAttributedString;

- (G3Thread*) thread;
- (G3Thread*) threadCreate: (BOOL) doCreate;

- (G3Profile *)profile;
- (void) setProfile: (G3Profile *)value;

- (NSArray*) commentsInThread: (G3Thread*)thread;

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

