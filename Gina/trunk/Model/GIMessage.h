//
//  GIMessage.h
//  Gina
//
//  Created by Dirk Theisen on 22.07.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "OPPersistentObjectContext.h"

@class GIProfile;
@class OPFaultingArray;
@class OPInternetMessage;

#define OPSeenStatus 1
#define OPAnsweredStatus 2
#define OPFlaggedStatus 4
#define OPDummyStatus 8
#define OPResentStatus 16 // redirected
//#define OPRecentStatus 32
//#define OPQueuedStatus 64
//#define OPExpungedStatus 128
#define OPInterestingStatus 256
//#define OPSendingBlockedStatus 512
//#define OPPublicMessageStatus 1024
#define OPFulltextIndexedStatus 2048
//#define OPInSendJobStatus 4096
#define OPJunkMailStatus 8192
#define OPIsFromMeStatus 16384

// Possible values for -sendStatus:
#define OPSendStatusNone 0

// The message has been saved as draft for later editing. Do not send it:
#define OPSendStatusDraft 1

// The message has been queued but is currently edited or may not be sent for some other reason:
#define OPSendStatusQueuedBlocked 2

// The message has been queued and is ready to be send:
#define OPSendStatusQueuedReady 3

// The message is being send to the server and may not be edited any more:
#define OPSendStatusSending 4

extern NSString *GIMessageDidChangeFlagsNotification;

@class GIThread;

@interface GIMessage : OPPersistentObject 
{
@private
	NSString *messageId;
	NSString *subject;
	NSString *to;
	NSDate *date;
	NSString *senderName;
	OID threadOID;
	OID referenceOID;
	NSArray *comments; // transient cache
    unsigned flags; 
	OPInternetMessage *internetMessage;
	unsigned referenceCount;
	unsigned unreadMessageCount;
	unsigned sendStatus;
}

/*" Basic properties "*/
@property (readonly) NSString *to;
@property (readonly) NSString *subject;
@property (readonly) NSDate *date;
@property (readonly) NSString *messageId;
@property (readonly) NSString *senderName;
@property (readonly) NSUInteger unreadMessageCount;
@property (readonly) unsigned flags;
@property (readwrite) unsigned sendStatus;

@property (readonly) OPInternetMessage *internetMessage;
@property (retain) GIThread *thread;
@property (retain) GIMessage *reference;

/*" Derived properties "*/
@property BOOL isSeen;
@property BOOL isDummy;
@property (readonly) NSUInteger numberOfReferences;
@property (readonly) NSString *messageFilePath;
@property (readonly) NSString *recipientsForDisplay;

/*" Message type inquiry "*/
@property (readonly) BOOL isListMessage;
@property (readonly) BOOL isUsenetMessage;
@property (readonly) BOOL isEMailMessage;
@property (readonly) BOOL isPublicMessage;

/*" Accessing body content "*/
@property (readonly) NSAttributedString *contentAsAttributedString;
@property (readonly) NSString *contentAsString;

/*" Factory and init methods "*/
+ (id)messageWithInternetMessage:(OPInternetMessage *)anInternetMessage appendToAppropriateThread:(BOOL)doThread;
+ (id)dummyMessageWithId:(NSString *)aMessageId andDate:(NSDate *)aDate;

- (id)initWithInternetMessage:(OPInternetMessage *)anInternetMessage appendToAppropriateThread:(BOOL)doThread forcedMessageId:(NSString *)forcedMessageId;
- (id) initDummy;

- (void)setContentFromInternetMessage:(OPInternetMessage *)im appendToAppropriateThread:(BOOL)doThread forcedMessageId:(NSString *)forcedMessageId;

/*" Cache flushing "*/
- (void) flushNumberOfReferencesCache;
- (void) flushInternetMessageCache;

/*" Flag handling "*/
- (BOOL) hasFlags: (unsigned int) someFlags;
- (void) toggleFlags: (unsigned) someFlags;

- (BOOL)isSeen;
- (void)setIsSeen:(BOOL)boolValue;

- (NSString *)flagsString; // use only for export
- (void)addFlagsFromString:(NSString *)flagsString; // use only for import

/*" Earliest send time handling "*/
- (NSDate*) earliestSendTime;
- (void) setEarliestSendTime: (NSDate*) aDate;
+ (void) repairEarliestSendTimes;

/*" Miscellaneous methods "*/

- (NSMutableArray*) commentsInThread: (GIThread*) aThread;
- (void) addOrderedSubthreadToArray: (NSMutableArray*) result;

@end


