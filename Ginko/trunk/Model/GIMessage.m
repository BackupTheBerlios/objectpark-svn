//
//  GIMessage.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 22.07.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "GIMessage.h"
#import "GIProfile.h"
#import "GIThread.h"
#import "OPInternetMessage.h"
#import "NSString+MessageUtils.h"
#import "OPPersistentObject+Extensions.h"
#import "OPInternetMessage+GinkoExtensions.h"
#import "OPManagedObject.h"
#import "GIMessageGroup.h"
#import "GIMessageBase.h"
#import "GIApplication.h"
#import "OPPersistentObject+Extensions.h"
#import <Foundation/NSDebug.h>
#import "GIFulltextIndex.h"


#define MESSAGE    OPL_DOMAIN  @"Message"
#define DUPECHECK  OPL_ASPECT  0x01
#define FLAGS      OPL_ASPECT  0x02


@implementation GIMessage


+ (NSString*) databaseProperties
{
	return 
	@"{"
	@"  TableName = ZMESSAGE;"
	@"  CreateStatements = (\""
	@"  CREATE TABLE ZMESSAGE (Z_ENT INTEGER, Z_PK INTEGER PRIMARY KEY, Z_OPT INTEGER, ZISANSWERED INTEGER, ZISFLAGGED INTEGER, ZMESSAGEID VARCHAR, ZISFULLTEXTINDEXED INTEGER, ZISSEEN INTEGER, ZISINTERESTING INTEGER, ZAUTHOR VARCHAR, ZISFROMME INTEGER, ZISDRAFT INTEGER, ZISQUEUED INTEGER, ZSUBJECT VARCHAR, ZDATE TIMESTAMP, ZISJUNK INTEGER, ZTHREAD INTEGER, ZPROFILE INTEGER, ZREFERENCE INTEGER, ZMESSAGEDATA INTEGER)"
	@"  \",\""
	@"  CREATE INDEX ZMESSAGE_ZREFERENCE_INDEX ON ZMESSAGE (ZREFERENCE)"
	@"  \",\""
	@"  CREATE INDEX ZMESSAGE_ZTHREAD_INDEX ON ZMESSAGE (ZTHREAD)"
	@"  \",\""
	@"  CREATE UNIQUE INDEX MY_MESSAGE_ID_INDEX ON ZMESSAGE (ZMESSAGEID)"
	@"  \");"
	@""
	@"}";
}

+ (NSString*) persistentAttributesPlist
{
	return 
	@"{"
	@"messageId = {ColumnName = ZMESSAGEID; AttributeClass = NSString;};"
	@"messageData = {ColumnName = ZMESSAGEDATA; AttributeClass = GIMessageData;};"
	@"subject = {ColumnName = ZSUBJECT; AttributeClass = NSString;};"
	@"date = {ColumnName = ZDATE; AttributeClass = NSCalendarDate;};"
	@"senderName = {ColumnName = ZAUTHOR; AttributeClass = NSString;};"
	@"sendProfile = {ColumnName = ZPROFILE; AttributeClass = GIProfile; InverseRelationshipKey = messagesToSend;};"
	@"thread = {ColumnName = ZTHREAD; AttributeClass = GIThread; InverseRelationshipKey = messages;};"
	@"reference = {ColumnName = ZREFERENCE; AttributeClass = GIMessage;};"
	// Flags
	@"isSeen = {ColumnName = ZISSEEN; AttributeClass = NSNumber;};"
	//@"isQueued = {ColumnName = ZISQUEUED; AttributeClass = NSNumber;};"
	//@"isSendingBlocked = {ColumnName = ZISQUEUED; AttributeClass = NSNumber;};"
	//@"isDraft = {ColumnName = ZISDRAFT; AttributeClass = NSNumber;};"
	@"isAnswered = {ColumnName = ZISANSWERED; AttributeClass = NSNumber;};"
	@"isFulltextIndexed = {ColumnName = ZISFULLTEXTINDEXED; AttributeClass = NSNumber;};"
	@"isFromMe = {ColumnName = ZISFROMME; AttributeClass = NSNumber;};"
	@"isFlagged = {ColumnName = ZISFLAGGED; AttributeClass = NSNumber;};"
	@"isJunk = {ColumnName = ZISJUNK; AttributeClass = NSNumber;};"
	@"isInteresting = {ColumnName = ZISINTERESTING; AttributeClass = NSNumber;};"
	//@"isInSendJob = {ColumnName = ZISQUEUED; AttributeClass = NSNumber;};"
	@"sendStatus = {ColumnName = ZISQUEUED; AttributeClass = NSNumber;};"

	@"}";
}

+ (NSArray*) messagesToAddToFulltextIndexWithLimit: (unsigned) limit
{
    OPPersistentObjectContext* context = [OPPersistentObjectContext defaultContext];
    
    NSArray* result = [context objectsForClass: self whereFormat: @"(ZISFULLTEXTINDEXED ISNULL or ZISFULLTEXTINDEXED==0) and (ZISJUNK ISNULL or ZISJUNK==0) limit ?", [NSNumber numberWithUnsignedInt: limit], nil];

    return result;
}

+ (NSArray*) messagesToRemoveFromFulltextIndexWithLimit: (unsigned) limit
{
    OPPersistentObjectContext* context = [OPPersistentObjectContext defaultContext];
    
    NSArray* result = [context objectsForClass: self whereFormat:@"(ZISFULLTEXTINDEXED NOTNULL and ZISFULLTEXTINDEXED <> 0) and (ZISJUNK NOTNULL and ZISJUNK <> 0) limit ?", [NSNumber numberWithUnsignedInt: limit], nil];
    
    return result;
}

+ (id) messageForMessageId: (NSString*) messageId
/*" Returns either nil or the message specified by its messageId. "*/
{
	GIMessage* result = nil;

    if (messageId) {
		OPPersistentObjectContext* context = [OPPersistentObjectContext defaultContext];
		NSArray* objects = [context objectsForClass: self whereFormat: @"ZMESSAGEID=?", messageId, nil];
		
		//[objectEnum reset]; // optional
		//[objectEnum bind:messageId, nil]; // only necessary for requests containing question mark placeholders
		
		result = [objects lastObject];
		//[objectEnum reset]; // might free some memory.
        
        if (! result)
        {;
            @synchronized(context)
            {
                // look in changed objects
                NSEnumerator *enumerator = [[context changedObjects] objectEnumerator];
                OPPersistentObject *changedObject;
                while (changedObject = [enumerator nextObject]) 
                {
                    if ([changedObject isKindOfClass:[GIMessage class]])
                    {
                        if ([[changedObject valueForKey: @"messageId"] isEqualToString:messageId])
                        {
                            result = (GIMessage *)changedObject;
                            break;
                        }
                    }
                }
            }
        }
	}
    
	return result;
}

- (void) willSave
{
	[super willSave];
	if (![self valueForKey: @"thread"]) NSLog(@"Warning! Will save message without thread!", self);
}


- (void) willDelete
{
	// remove message from fulltext index
    //[GIFulltextIndex removeMessagesWithIds: [NSArray arrayWithObject: [self messageId]]];
	
	GIThread* thread = [self valueForKey: @"thread"];
	if (thread) {
		//[self setValue: nil forKey: @"thread"];

		if ([thread messageCount]<=1) {
			[thread delete]; 
		}
	}
	[[self valueForKey: @"messageData"] delete];
	[super willDelete];
}

/* not necessary -threads are re-created on change 
- (void) setSubject: (NSString*) subject
{
	[self willAccessValueForKey: @"subject"];
	[self setPrimitiveValue: subject forKey: @"subject"];
	[self didAccessValueForKey: @"subject"];
	GIThread* thread = [self valueVorKey: @"thread"];
	if ([thread containsSingleMessage]) {
		[thread setValue: subject forKey: @"subject"];
	}
}
*/

- (void) flushInternetMessageCache
	/*" Flushes the cache for the internetMessageCache transient attribute. Used for optimized memory usage. "*/
{
    [attributes removeObjectForKey: @"internetMessageCache"];
}

- (NSData*) transferData
{
	return [self valueForKeyPath: @"messageData.transferData"];
}

- (void) setTransferData: (NSData*) newData
{
	GIMessageData* messageData = [self valueForKey: @"messageData"];
	if (!messageData) {
		messageData = [[[GIMessageData alloc] init] autorelease];
		[self willChangeValueForKey: @"transferData"];
		[self setPrimitiveValue: messageData forKey: @"messageData"];
		[self didChangeValueForKey: @"transferData"];
	}
	[self setPrimitiveValue: nil forKey: @"internetMessageCache"];
	// We now have a valid messageData object to upate:
	[messageData setValue: newData forKey: @"transferData"];	
}

- (OPInternetMessage*) internetMessage
{
    OPInternetMessage* cache = [self primitiveValueForKey: @"internetMessageCache"];
    if (!cache) {
        NSData* transferData = [self valueForKey: @"transferData"];
        
        if (transferData) {
            cache = [[OPInternetMessage alloc] initWithTransferData: transferData];
            [self setPrimitiveValue: cache forKey: @"internetMessageCache"];
            [cache release];
        }
    } 
    //else NSLog(@"using cached imessage data"); // remove this after testing.
    return cache;
}

+ (id) messageWithTransferData: (NSData*) someTransferData
	/*" Returns a new message with the given transfer data someTransferData in the managed object context aContext. If message is a dupe, the message not inserted into the context nil is returned. "*/
{
    id result = nil;
    OPInternetMessage* im = [[OPInternetMessage alloc] initWithTransferData: someTransferData];
    BOOL insertMessage = NO;
    
    GIMessage* dupe = [self messageForMessageId: [im messageId]];
    if (dupe) {
        if ([GIProfile isMyEmailAddress: [im fromWithFallback: YES]]) {
            //replace old message with new:
            [dupe delete];
            //[NSApp saveAction: self]; // needed here?
            insertMessage = YES;
        }
        OPDebugLog(MESSAGE, DUPECHECK, @"Dupe for message id %@ detected.", [im messageId]);        
    } else {
        insertMessage = YES;
    }
    
    if (insertMessage) {
        // Create a new message in the default context:
        result = [[[GIMessage alloc] init] autorelease];
		[result insertIntoContext: [OPPersistentObjectContext threadContext]]; 
		NSAssert(result != nil, @"Could not create message object");
        
        NSString *fromHeader = [im fromWithFallback: YES];
        
        [result setPrimitiveValue: im forKey: @"internetMessageCache"];
        [result setValue: someTransferData forKey: @"transferData"];
        [result setValue: [im messageId] forKey: @"messageId"];  
        [result setValue: [im normalizedSubject] forKey: @"subject"];
        [result setValue: [fromHeader realnameFromEMailStringWithFallback] forKey: @"senderName"];
        
        // sanity check for date header field:
        NSCalendarDate* messageDate = [im date];
        if ([(NSDate*) [NSDate dateWithTimeIntervalSinceNow: 15 * 60.0] compare: messageDate] != NSOrderedDescending) {
			// if message's date is a future date
			// broken message, set current date:
            messageDate = [NSCalendarDate date];
            if (NSDebugEnabled) NSLog(@"Found message with future date. Fixing broken date with 'now'.");
        }
        [result setValue: messageDate forKey: @"date"];
        
        // Note that this method operates on the encoded header field. It's OK because email
        // addresses are 7bit only.
        if ([GIProfile isMyEmailAddress: fromHeader]) {
            [result addFlags: OPIsFromMeStatus];
        }
    }
    
    [im release];
    return result;
}

- (BOOL) isUsenetMessage
	/*" Returns YES, if Ginko thinks (from the message headers) that this message is an Usenet News article (note, that a message can be both, a usenet article and an email). This message causes the message to be decoded. "*/
{
    return ([[self internetMessage] bodyForHeaderField: @"Newsgroups"] != nil);
}

- (BOOL) isEMailMessage
	/*" Returns YES, if Ginko thinks (from the message headers) that this message is some kind of email (note, that a message can be both, a usenet article and an email). This message causes the message to be decoded. "*/
{
    return ([[self internetMessage] bodyForHeaderField: @"To"] != nil);
}

- (BOOL) isPublicMessage 
{
    return [self isListMessage] || [self isUsenetMessage];
}

- (id) init 
{
	if (self = [super init]) {
		flagsCache = -1;
	}
	return self;
}

- (BOOL) isDummy
{
    return [self transferData] == nil;
}

- (unsigned) flags
{
    @synchronized(self)
    {
        if (flagsCache < 0) {
            flagsCache = 0;
            
			[self willAccessValueForKey: @"isSeen"];

            //if ([self primitiveBoolForKey: @"isInSendJob"]) flagsCache |= OPInSendJobStatus; // not in db schema!?
            //if ([self primitiveBoolForKey: @"isQueued"]) flagsCache |= OPQueuedStatus;
            if ([self primitiveBoolForKey: @"isInteresting"]) flagsCache |= OPInterestingStatus;
            if ([self primitiveBoolForKey: @"isSeen"]) flagsCache |= OPSeenStatus;
            if ([self primitiveBoolForKey: @"isJunk"]) flagsCache |= OPJunkMailStatus;
            //if ([self primitiveBoolForKey: @"isSendingBlocked"]) flagsCache |= OPSendingBlockedStatus;
			if ([self primitiveBoolForKey: @"isFlagged"]) flagsCache |= OPFlaggedStatus;
			if ([self primitiveBoolForKey: @"isFromMe"]) flagsCache |= OPIsFromMeStatus;
            if ([self primitiveBoolForKey: @"isFulltextIndexed"]) flagsCache |= OPFulltextIndexedStatus;
            if ([self primitiveBoolForKey: @"isAnswered"]) flagsCache |= OPAnsweredStatus;
            //if ([self primitiveBoolForKey: @"isDraft"]) flagsCache |= OPDraftStatus;
			
			[self didAccessValueForKey: @"isSeen"];
        }
    }    
    return flagsCache;
}

- (NSString*) messageId
{
	[self willAccessValueForKey: @"messageId"];
    id result = [self primitiveValueForKey: @"messageId"];
	[self didAccessValueForKey: @"messageId"];
	return result;
}

- (unsigned) numberOfReferences
	/*" Returns the number of referenced messages until a root message is reached. "*/
{
	[self willAccessValueForKey: @"numberOfReferences"];
    NSNumber* cachedValue = [self primitiveValueForKey: @"numberOfReferences"];
	[self didAccessValueForKey: @"numberOfReferences"];
    if (cachedValue) return [cachedValue unsignedIntValue];
    if (![self reference]) return 0;
    cachedValue = [NSNumber numberWithUnsignedInt: [[self reference] numberOfReferences]+1];
    [self setPrimitiveValue: cachedValue forKey: @"numberOfReferences"];
    return [cachedValue unsignedIntValue];
}

- (void) flushNumberOfReferencesCache
{
	[attributes removeObjectForKey: @"numberOfReferences"];
}

- (NSArray*) commentsInThread: (GIThread*) thread
	/* Returns all directly commenting messages in the thread given. */
{
    NSEnumerator* me = [[thread messages] objectEnumerator];
    NSMutableArray* result = [NSMutableArray array];
    GIMessage* other;
    while (other = [me nextObject]) {
        if ([other reference] == self) {
            [result addObject: other];
        }
    }
    return result;
}

- (NSAttributedString*) contentAsAttributedString
{
    return [[self internetMessage] bodyContent];
}


- (GIThread*) assignThreadUseExisting: (BOOL) useExisting
	/*" Returns the one thread the message belongs to. If useExisting is NO, this method creates a new thread in the receiver's context containing just the receiver, otherwise, it uses the message reference to find an existing thread object. "*/
{
    GIThread* thread = [self thread];
    
	if (!thread) {
		if (useExisting) {
			// do threading by reference
			thread = [[self referenceFind: YES] thread];
        }
		if (!thread) {
            thread = [[[GIThread alloc] init] autorelease];
			[thread insertIntoContext: [self context]];
            [thread setValue: [self valueForKey: @"subject"] forKey: @"subject"];
			[thread setValue: [self valueForKey: @"date"] forKey: @"date"];
        } else {
             NSLog(@"Found Existing Thread with %d message(s). Updating it...", [thread messageCount]);
            // Set the thread's subject to be the first messages subject:
        }
        // We got one, so set it:
        [self setValue: thread forKey: @"thread"];
    }
    
    return thread;
}

- (NSString*) senderName
	/*" Returns the real name extracted from the 'From' header. "*/
{
	[self willAccessValueForKey: @"senderName"];
    NSString* result = [self primitiveValueForKey: @"senderName"];
	[self didAccessValueForKey: @"senderName"];

	return result;
}

- (GIThread*) thread
/*"  "*/
{
	[self willAccessValueForKey: @"thread"];
    id result = [self primitiveValueForKey: @"thread"];
	[self didAccessValueForKey: @"thread"];
	
	return result;
}


- (NSString*) flagsString
	/*" Returns a textual representation of some flags. Used for exporting messages, including their flags. Not all available flags are supported. "*/
{
    char result[sizeof(unsigned)*8+1];  // size of flags vector in bits + 1
    int i = 0;
    unsigned flags = [self flags];
    
    if (flags & OPInterestingStatus) result[i++] = 'I';
    if (flags & OPAnsweredStatus)    result[i++] = 'A';
    if (flags & OPJunkMailStatus)    result[i++] = 'J';
    if (flags & OPSeenStatus)        result[i++] = 'R';
    //if (flags & OPDraftStatus)       result[i++] = 'D';
    
    result[i++] = '\0'; // terminate string
    
    return [NSString stringWithCString: result];
}


- (void) addFlagsFromString: (NSString*) flagsString
	/*" Not all available flags are supported. "*/
{
    unsigned flags = 0;
    
    int flagsCount = [flagsString length];
    for (int i = 0; i < flagsCount; i++) {
        unichar flagChar = [flagsString characterAtIndex:i];
        
        switch (flagChar) {
            case 'I': flags |= OPInterestingStatus;
                      break;
            case 'A': flags |= OPAnsweredStatus;
                      break;
            case 'J': flags |= OPJunkMailStatus;
                      break;
            case 'R': flags |= OPSeenStatus;
                      break;
//             case 'D': flags |= OPDraftStatus;
//                       break;
            default: OPDebugLog(MESSAGE, FLAGS, @"Unknown flag character in flags string: '%C' (0x%X)", flagChar, flagChar);
        }
    }
    
    [self addFlags:flags];
}


- (BOOL) hasFlags: (unsigned) someFlags
{
    return (someFlags & [self flags]) == someFlags;
}

+ (void) resetSendStatus
/*" Run during startup to set the sendStatus of OPSendStatusSending or OPSendStatusQueuedBlocked back to OPSendStatusQueuedReady "*/
{
	NSString* command = @"update ZMESSAGE set ZISQUEUED=3 where ZISQUEUED=2 or ZISQUEUED=4;";
	[[[OPPersistentObjectContext defaultContext] databaseConnection] performCommand: command];
}

- (unsigned) sendStatus
{
	[self willAccessValueForKey: @"sendStatus"];
	id result = [self primitiveValueForKey: @"sendStatus"];
	[self didAccessValueForKey: @"sendStatus"];	
	unsigned intResult = [result intValue];
	NSLog(@"SendStatus of %@ is %u", self, result);
	NSAssert2(intResult<=OPSendStatusSending, @"Illegal send status of %@: %@ detected.", self, result);
	NSAssert(intResult==0 || [self valueForKey: @"sendProfile"] !=nil, @"No profile set, but send status");
	return intResult;
}

- (void) setSendStatus: (unsigned) newStatus
{
	NSParameterAssert(newStatus<=OPSendStatusSending);
	[self willChangeValueForKey: @"sendStatus"];
	[self setPrimitiveValue: newStatus == 0 ? nil : [NSNumber numberWithInt: newStatus] forKey: @"sendStatus"];
	[self didChangeValueForKey: @"sendStatus"];
	NSLog(@"SendStatus of %@ changed to %u", self, newStatus);
}


- (void) addFlags: (unsigned) someFlags
{
    @synchronized(self) {
        int flags = [self flags];
		someFlags = (0xffffffff ^ flags) & someFlags;
        if (someFlags) {
            // flags to set:
            NSNumber* yes = [NSNumber numberWithBool: YES];
//#warning isInSendJob not in DB schema ignored.
            //if ((someFlags & OPInSendJobStatus)) [self setValue: yes forKey: @"isInSendJob"]; // not in DB schema!?
//            if ((someFlags & OPQueuedStatus)) [self setValue: yes forKey: @"isQueued"];
            if ((someFlags & OPInterestingStatus)) [self setValue: yes forKey: @"isInteresting"];
            if ((someFlags & OPSeenStatus)) [self setValue: yes forKey: @"isSeen"];
            if ((someFlags & OPJunkMailStatus)) [self setValue: yes forKey: @"isJunk"];
//#warning isSendingBlocked not in DB schema ignored.
            //if ((someFlags & OPSendingBlockedStatus)) [self setValue: yes forKey: @"isSendingBlocked"];
            if ((someFlags & OPFlaggedStatus)) [self setValue: yes forKey: @"isFlagged"];
            if ((someFlags & OPIsFromMeStatus)) [self setValue: yes forKey: @"isFromMe"];
            if ((someFlags & OPFulltextIndexedStatus)) [self setValue: yes forKey: @"isFulltextIndexed"];
            if ((someFlags & OPAnsweredStatus)) [self setValue: yes forKey: @"isAnswered"];
//            if ((someFlags & OPDraftStatus)) [self setValue: yes forKey: @"isDraft"];
			
            flagsCache = someFlags | flags;
        }
    }
}

/*
- (void) setValue: (id) value forKey: (NSString*) key
{
	[super setValue: value forKey: key];
}

- (void) willSave
{
	NSLog(@"Will save %@", self);
}
*/

- (void) removeFlags:(unsigned)someFlags
{
    @synchronized(self) {
        int flags = [self flags];
        
        if ((flags & (~someFlags)) != flags) {
            // flags to remove:
            //NSNumber* no = [NSNumber numberWithBool: NO];
            //if (someFlags & OPInSendJobStatus) [self setValue: nil forKey: @"isInSendJob"];
            //if (someFlags & OPQueuedStatus) [self setValue: nil forKey: @"isQueued"];
            if (someFlags & OPInterestingStatus) [self setValue: nil forKey: @"isInteresting"];
            if (someFlags & OPSeenStatus) [self setValue: nil forKey: @"isSeen"];
            if (someFlags & OPJunkMailStatus) [self setValue: nil forKey: @"isJunk"];
            //if (someFlags & OPSendingBlockedStatus) [self setValue: nil forKey: @"isSendingBlocked"];
            if (someFlags & OPFlaggedStatus) [self setValue: nil forKey: @"isFlagged"];
            if (someFlags & OPIsFromMeStatus) [self setValue: nil forKey: @"isFromMe"];
            if (someFlags & OPFulltextIndexedStatus) [self setValue: nil forKey: @"isFulltextIndexed"];
            if (someFlags & OPAnsweredStatus) [self setValue: nil forKey: @"isAnswered"];
            //if (someFlags & OPDraftStatus) [self setValue: nil forKey: @"isDraft"];
            
            flagsCache = (flags & (~someFlags));
        }
    }
}

- (GIMessage *)reference
/*" Returns the direct message reference stored. "*/
{
    [self willAccessValueForKey: @"reference"];
    id reference = [self primitiveValueForKey: @"reference"];
    [self didAccessValueForKey: @"reference"];
    return reference;
}

- (GIMessage*) referenceFind: (BOOL) find
/*" Returns the direct message reference stored. If there is none and find is YES, looks up the references header(s) in the internet message object and caches the result (if any). "*/
{
    GIMessage* result = [self reference];
    
    if (!result && find) {
        NSEnumerator* enumerator = [[[self internetMessage] references] reverseObjectEnumerator];
        NSString* refId;
        while (refId = [enumerator nextObject])  {
            if (result = [[self class] messageForMessageId: refId])  {
                [self setValue: result forKey: @"reference"];
                return result;
            }
        }
    }
    return result;
}

- (BOOL) isListMessage
	/*" Returns YES, if Ginko thinks (from the message headers) that this message is from a mailing list (note, that a message can be both, a usenet article and an email). Decodes internet message to compute the result - so it may be slow! "*/
{
    OPInternetMessage* m = [self internetMessage];   
    
    // do more guesses here...
    return (([m bodyForHeaderField: @"List-Post"] != nil)
            || ([m bodyForHeaderField: @"List-Id"] != nil)
            || ([m bodyForHeaderField: @"X-List-Post"] != nil));
}

@end

@implementation GIMessageData


//CREATE TABLE ZMESSAGEDATA ( Z_ENT INTEGER, Z_PK INTEGER PRIMARY KEY, Z_OPT INTEGER, ZTRANSFERDATA BLOB );

+ (NSString*) databaseProperties
{
	return 
	@"{"
	@"  TableName = ZMESSAGEDATA;"
	@"  CreateStatements = (\""
	@"	CREATE TABLE ZMESSAGEDATA (Z_ENT INTEGER, Z_PK INTEGER PRIMARY KEY, Z_OPT INTEGER, ZTRANSFERDATA BLOB)"
	@"  \");"
	@""
	@"}";
}

+ (NSString*) persistentAttributesPlist
{
	return 
	@"{"
	@"transferData = {ColumnName = ZTRANSFERDATA; AttributeClass = NSData;};"
	@"}";
}

@end
