//
//  GIMessage.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 22.07.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "OPPersistentObject.h"

//@class GIThread;
@class GIProfile;
@class OPInternetMessage;
@class OPFaultingArray;

#define OPSeenStatus 1
#define OPAnsweredStatus 2
#define OPFlaggedStatus 4
//#define OPDeletedStatus 8
//#define OPDraftStatus 16
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

@class GIThread;
@class OPInternetMessage;

@interface GIMessage : OPPersistentObject {
@private
	NSString* messageId;
	NSString* subject;
	NSString* to;
	NSDate* date;
	NSString* senderName;
	OID sendProfileOID;
	OID threadOID;
	OID referenceOID;
	NSArray* comments; // transient cache
    unsigned flags; 
	OPInternetMessage* internetMessage;
}

@property (readonly, retain) OPInternetMessage *internetMessage;
@property OID referenceOID;
@property (readonly, retain) NSString* subject;
@property (readonly, retain) NSDate* date;
@property (readonly, retain) NSString* messageId;
@property (retain) GIThread* thread;



//+ (NSString*) persistentAttributesPlist
//{
//	return 
//	@"{"
//	@"messageId = {ColumnName = ZMESSAGEID; AttributeClass = NSString;};"
//	@"messageData = {ColumnName = ZMESSAGEDATA; AttributeClass = GIMessageData;};"
//	@"subject = {ColumnName = ZSUBJECT; AttributeClass = NSString;};"
//	@"to = {ColumnName = ZTO; AttributeClass = NSString;};"
//	@"date = {ColumnName = ZDATE; AttributeClass = NSCalendarDate;};"
//	@"senderName = {ColumnName = ZAUTHOR; AttributeClass = NSString;};"
//	@"sendProfile = {ColumnName = ZPROFILE; AttributeClass = GIProfile; InverseRelationshipKey = messagesToSend;};"
//	@"thread = {ColumnName = ZTHREAD; AttributeClass = GIThread; InverseRelationshipKey = messages;};"
//	@"reference = {ColumnName = ZREFERENCE; AttributeClass = GIMessage;};"
//	// Flags
//	@"isSeen = {ColumnName = ZISSEEN; AttributeClass = NSNumber;};"
//	@"isAnswered = {ColumnName = ZISANSWERED; AttributeClass = NSNumber;};"
//	@"isFulltextIndexed = {ColumnName = ZISFULLTEXTINDEXED; AttributeClass = NSNumber;};"
//	@"isFromMe = {ColumnName = ZISFROMME; AttributeClass = NSNumber;};"
//	@"isFlagged = {ColumnName = ZISFLAGGED; AttributeClass = NSNumber;};"
//	@"isJunk = {ColumnName = ZISJUNK; AttributeClass = NSNumber;};"
//	@"isInteresting = {ColumnName = ZISINTERESTING; AttributeClass = NSNumber;};"
//	@"sendStatus = {ColumnName = ZISQUEUED; AttributeClass = NSNumber;};"
//	
//	@"}";
//}
//





+ (void) resetSendStatus;

+ (id) messageForMessageId: (NSString*) messageId;
+ (id) dummyMessageWithId:(NSString*)aMessageId andDate:(NSDate*)aDate;
+ (id)messageWithInternetMessage:(OPInternetMessage *)anInternetMessage;

- (id) initWithInternetMessage:(OPInternetMessage *)anInternetMessage;

- (GIMessage*) reference;
- (GIMessage*) referenceFind: (BOOL)find;

- (unsigned) numberOfReferences;
- (void) flushNumberOfReferencesCache;

- (unsigned int)flags;
- (BOOL)hasFlags:(unsigned int)someFlags;
- (void)addFlags:(unsigned int)someFlags;
- (void)removeFlags:(unsigned int)someFlags;

/*" Special flag handling "*/
- (void)setIsSeen:(NSNumber *)aBoolean;

- (unsigned)sendStatus;
- (void)setSendStatus:(unsigned)newStatus;
- (NSDate *)earliestSendTime;
- (void)setEarliestSendTime:(NSDate *)aDate;
+ (void)repairEarliestSendTimes;

- (NSString *)flagsString; // use only for export
- (void)addFlagsFromString:(NSString *)flagsString; // use only for import

- (NSAttributedString *)contentAsAttributedString;
- (NSString*) contentAsString;

//- (GIThread*) assignThreadUseExisting: (BOOL) useExisting;

- (NSArray*) commentsInThread: (GIThread*) thread;

- (BOOL) isListMessage;
- (BOOL) isUsenetMessage;
- (BOOL) isEMailMessage;
- (BOOL) isPublicMessage;
- (BOOL) isDummy;

- (NSString*) senderName;
- (NSString*) recipientsForDisplay;

- (void) addOrderedSubthreadToArray: (NSMutableArray*) result;

@end

extern NSString* GIMessageDidChangeFlagsNotification;

@interface GIMessageData : OPPersistentObject {
}
 
@end
