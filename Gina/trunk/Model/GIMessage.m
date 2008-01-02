//
//  GIMessage.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 22.07.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "GIMessage.h"
#import <Foundation/NSDebug.h>
#import "GIProfile.h"
#import "GIThread.h"
#import "OPInternetMessage.h"
#import "NSString+MessageUtils.h"
//#import "OPInternetMessage+GinkoExtensions.h"
#import "GIMessageGroup.h"
//#import "GIMessageBase.h"
#import "GIApplication.h"
#import "OPPersistentObjectContext.h"
//#import <Foundation/NSDebug.h>
//#import "NSArray+Extensions.h"
#import "GIUserDefaultsKeys.h"
//#import "EDMessagePart+OPExtensions.h"
#import "OPPersistentStringDictionary.h"

NSString *GIMessageDidChangeFlagsNotification = @"GIMessageDidChangeFlagsNotification";

#define MESSAGE           OPL_DOMAIN  @"Message"
#define DUPECHECK         OPL_ASPECT  0x01
#define FLAGS             OPL_ASPECT  0x02
#define DUMMYCREATION     OPL_ASPECT  0x04
#define MESSAGEREPLACING  OPL_ASPECT  0x08

@interface OPPersistentObjectContext (GIModelExtensions)

- (NSString*) transferDataDirectory;

@end


@implementation GIMessage

@synthesize date;
@synthesize subject;
@synthesize internetMessage;

+ (NSMutableDictionary*) messagesByMessageId
{
	OPPersistentObjectContext* context = [OPPersistentObjectContext defaultContext];
	
	OPPersistentStringDictionary* globalIndex = nil;
	
	if (!globalIndex) {
		globalIndex = [[context rootObjectForKey: @"MessagesById"] retain];
		if (!globalIndex) {
			if (!NSDebugEnabled) {
				globalIndex = [[OPPersistentStringDictionary alloc] init]; 
			}
			[context setRootObject: globalIndex forKey: @"MessagesById"];
		} else {
			NSLog(@"Reusing messageId Index 0x%x", globalIndex);
		}
	}
	return globalIndex;
}

+ (id)messageForMessageId:(NSString *)messageId
/*" Returns either nil or the message specified by its messageId. "*/
{
	GIMessage* result = [[self messagesByMessageId] objectForKey: messageId];
	return result;
}



- (GIThread*) thread
{
	return [[self context] objectForOID: threadOID];
}

- (void) setThread: (GIThread*) aThread
{
	if (threadOID != [aThread oid]) {
		[self willChangeValueForKey: @"thread"];
		if (threadOID) {
			[[self.thread mutableArrayValueForKey: @"messages"] removeObject: self];
		}
		threadOID = [aThread oid];
		if (threadOID) {
			[[self.thread mutableArrayValueForKey: @"messages"] addObject: self];
		}
		[self didChangeValueForKey: @"thread"];
	}
}


- (void) willDelete
{
	id thread = [self valueForKey: @"thread"];
	if (thread) {
		[self setValue: nil forKey: @"thread"];

		if ([thread messageCount]<=1) {
			[thread delete]; 
		}
	}
#warning delete message file here!
	
	[[[self class] messagesByMessageId] removeObjectForKey: self.messageId];
	
	[super willDelete];
}

- (NSString*) messageFilename
{
	NSString* filename = [NSString stringWithFormat: @"%@/Msg%08x.gml", [[self context] transferDataDirectory], LIDFromOID([self oid])];
	return filename;
}

/*
- (NSData*) transferData
{
	if (! transferData) {
		transferData = [[NSData alloc] initWithContentsOfMappedFile: [self messageFilename]];
	}
	return transferData;
}
*/

//- (void) setTransferData: (NSData*) newData
//{
//	GIMessageData* messageData = newData ? [self valueForKey: @"messageData"] : nil;
//	if (messageData) {
//		// Reuse existing GIMessageData object!
//		// Make sure we re-index this message.
//		[self removeFlags: OPFulltextIndexedStatus];
//	} else {
//		if (newData) messageData = [[[GIMessageData alloc] init] autorelease];
//		[self willChangeValueForKey: @"transferData"];
//		[self setPrimitiveValue: messageData forKey: @"messageData"];
//		[self didChangeValueForKey: @"transferData"];
//	} 
//	[self flushInternetMessageCache];
//	// We now have a valid messageData object to upate:
//	[messageData setValue: newData forKey: @"transferData"];	
//}

//- (OPInternetMessage*) internetMessage
//{
//    OPInternetMessage* cache = [self transientValueForKey: @"internetMessageCache"];
//    if (!cache) {
//        NSData* transferData = [self valueForKey: @"transferData"];
//        
//        if (transferData) {
//            cache = [[OPInternetMessage alloc] initWithTransferData: transferData];
//            [self setTransientValue: cache forKey: @"internetMessageCache"];
//            [cache release];
//        }
//    } 
//    //else NSLog(@"using cached imessage data"); // remove this after testing.
//    return cache;
//}


+ (id) dummyMessageWithId:(NSString*)aMessageId andDate:(NSDate*)aDate
{
    GIMessage* dummy;
    
    // if there already is a message with that id we'll use that
	// This may not be dummy! So what happens then?
    if (dummy = [self messageForMessageId:aMessageId])
        return dummy;
        
    if (NSDebugEnabled) NSLog(@"creating dummy message for message id %@", aMessageId);
    
    dummy = [[[GIMessage alloc] init] autorelease];
    //[dummy insertIntoContext: [OPPersistentObjectContext threadContext]]; 
    NSAssert(dummy != nil, @"Could not create a dummy message object");

    [dummy setValue:aMessageId forKey:@"messageId"];  

    // dummy messages should not show up as unread
    [dummy addFlags:OPSeenStatus];
    
	NSAssert([dummy isDummy], @"Dummy message not marked as such");
	
    return dummy;
}


- (void) setContentFromInternetMessage: (OPInternetMessage*) im
{
    NSString* fromHeader = [im fromWithFallback: YES];
    
    if ([self isDummy])
        [self removeFlags: OPSeenStatus];
        
	internetMessage = [im retain];
	messageId = [[im messageId] retain];
//    [self setValue: [im messageId] forKey: @"messageId"];  
    subject = [[im normalizedSubject] retain];
    [self setValue: [fromHeader realnameFromEMailStringWithFallback] forKey: @"senderName"];
    
    // sanity check for date header field:
    NSCalendarDate* messageDate = [im date];
    if ([(NSDate*) [NSDate dateWithTimeIntervalSinceNow: 15 * 60.0] compare: messageDate] != NSOrderedDescending) {
        // if message's date is a future date
        // broken message, set current date:
        messageDate = [NSCalendarDate date];
		if (NSDebugEnabled) NSLog(@"Found message with future date. Fixing broken date with 'now'.");
    }
    [self setValue: messageDate forKey: @"date"];
    
    // Note that this method operates on the encoded header field. It's OK because email
    // addresses are 7bit only.
    if ([GIProfile isMyEmailAddress: fromHeader]) {
        [self addFlags: OPIsFromMeStatus];
    }
}

/*" Returns a new message with the internetmessage object.
 If message is a dupe, the message not inserted into the context nil is returned. "*/
+ (id)messageWithInternetMessage:(OPInternetMessage *)anInternetMessage;
{
    id result = nil;
    
    GIMessage *dupe = [self messageForMessageId:[anInternetMessage messageId]];
    
	if (dupe) 
	{
        if ([dupe isDummy]) 
		{
            // replace message
			if (NSDebugEnabled) NSLog(@"Replacing content for dummy message with oid %qu (msgId: %@)", [dupe oid], [anInternetMessage messageId]);
            [dupe setContentFromInternetMessage:anInternetMessage];
            [dupe referenceFind:YES];
        }
        else if ([GIProfile isMyEmailAddress:[anInternetMessage fromWithFallback:YES]]) 
		{
            // replace old message with new:
			if (NSDebugEnabled) NSLog(@"Replacing content for own message with oid %qu (msgId: %@)", [dupe oid], [anInternetMessage messageId]);
            [dupe setContentFromInternetMessage:anInternetMessage];
        }
        else
			if (NSDebugEnabled) NSLog(@"Dupe for message id %@ detected.", [anInternetMessage messageId]);        
    }
    else 
	{
        // Create a new message in the default context:
        result = [[[GIMessage alloc] initWithInternetMessage: anInternetMessage] autorelease];
		NSAssert(result != nil, @"Could not create message object");
    }
    
    return result;
}

/*" Returns a new message with the internetmessage object.
 If message is a dupe, the message not inserted into the context nil is returned. "*/
- (id) initWithInternetMessage:(OPInternetMessage *)anInternetMessage;
{
    if (self = [super init]) {
		// Create a new message in the default context:
		internetMessage = [anInternetMessage retain];
        [self setContentFromInternetMessage: internetMessage];
		[[[self class] messagesByMessageId] setObject: self forKey: self.messageId];
    }
    
    return self;
}

/*" Returns YES, if Ginko thinks (from the message headers) that this message is an Usenet News article (note, that a message can be both, a usenet article and an email). This message causes the message to be decoded. "*/
- (BOOL)isUsenetMessage
{
    return ([[self internetMessage] bodyForHeaderField:@"Newsgroups"] != nil);
}

/*" Returns YES, if Ginko thinks (from the message headers) that this message is some kind of email (note, that a message can be both, a usenet article and an email). This message causes the message to be decoded. "*/
- (BOOL)isEMailMessage
{
    return ([[self internetMessage] bodyForHeaderField:@"To"] != nil);
}

- (BOOL)isPublicMessage 
{
    return [self isListMessage] || [self isUsenetMessage];
}

- (id)init 
{
	NSParameterAssert(NO);
	return nil;
}

- (BOOL) isLeaf
{
	return YES;
}

- (NSArray*) messages
{
	return nil; // just for the gui
}

- (BOOL)isDummy
{
    return self.internetMessage == nil;
}

@synthesize referenceOID;

//- (void)setIsSeen:(NSNumber *)aBoolean
//{
//	BOOL boolValue = [aBoolean boolValue];
//    [self willChangeValueForKey:@"isSeen"];
//    [self setPrimitiveValue:aBoolean forKey:@"isSeen"];
//	
//	NSNumber *oldValue = [NSNumber numberWithInt:flagsCache];
//    flagsCache = boolValue ? (flagsCache | OPSeenStatus) : -1;
//	NSNumber *newValue = [NSNumber numberWithInt:flagsCache];
//	
//    [self didChangeValueForKey:@"isSeen"];
//	
//	[[NSNotificationCenter defaultCenter] postNotificationName:GIMessageDidChangeFlagsNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:oldValue, @"oldValue", newValue, @"newValue", nil, nil]];
//	
//	[[self thread] willChangeValueForKey:@"hasUnreadMessages"];
//	[[self thread] didChangeValueForKey:@"hasUnreadMessages"];
//}

- (unsigned) flags
{
    return flags;
}

- (NSString *)messageId
{
	return [[messageId retain] autorelease];
}

- (unsigned) numberOfReferences
	/*" Returns the number of referenced messages until a root message is reached. "*/
{
	[self willAccessValueForKey: @"numberOfReferences"];
    NSNumber* cachedValue = [self primitiveValueForKey: @"numberOfReferences"];
	[self didAccessValueForKey: @"numberOfReferences"];
    
    if (cachedValue)
        return [cachedValue unsignedIntValue];
        
    if (![self reference])
        return 0;
        
    cachedValue = [NSNumber numberWithUnsignedInt: [[self reference] numberOfReferences]+1];
    [self setPrimitiveValue: cachedValue forKey: @"numberOfReferences"];
    
    return [cachedValue unsignedIntValue];
}

//- (void) flushNumberOfReferencesCache
//{
//	[attributes removeObjectForKey: @"numberOfReferences"];
//}

- (NSArray*) commentsInThread: (GIThread*) aThread
	/* Returns all directly commenting messages in the thread given. */
{
    NSMutableArray* result = [NSMutableArray array];
	for (GIMessage* other in [aThread messages]) {
        if ([other reference] == self) {
            [result addObject: other];
        }
    }
    return result;
}

- (NSArray*) comments
/*" Returns the (cached) comments in the receiver's thread. "*/
{
	NSArray* result = comments;
	if (!result) {
		comments = [[self commentsInThread: [self thread]] retain]; // fires fault
	}
	return result;
}

- (void) willRevert
{
	[comments release]; comments = nil;
}

- (void) dealloc
{
	[messageId release];
	[subject release];
	[to release];
	[date release];
	[senderName release];
	[comments release];
	[internetMessage release]; internetMessage = nil;
	[super dealloc];
}

//- (void) flushCommentsCache
///*" Needs to be called whenever any other message changes its reference to the receiver (additions or removals). Preferable in -setPrimitiviveReference:. "*/
//{
//	[attributes removeObjectForKey: @"comments"];
//}


- (NSAttributedString *)contentAsAttributedString
{
    return [[self internetMessage] bodyContent];
}

- (NSString *)contentAsString
{
   return [[self internetMessage] contentAsPlainString];
}

//- (GIThread*) assignThreadUseExisting: (BOOL) useExisting
///*"Returns the one thread the message belongs to.
//   If useExisting is NO, this method creates a new thread in the receiver's
//   context containing just the receiver, otherwise, it uses the message 
//   reference to find an existing thread object."*/
//{
//    GIThread* thread = [self thread];
//    
//	if (!thread) {
//		if (useExisting) {
//			// do threading by reference
//			thread = [[self referenceFind: YES] thread];
//        }
//		if (!thread) {
//            thread = [[[GIThread alloc] init] autorelease];
//			[thread insertIntoContext: [self context]];
//			// Set the thread's subject to be the first message's subject:
//            [thread setValue: [self valueForKey: @"subject"] forKey: @"subject"];
//        } else {
//             if (NSDebugEnabled) NSLog(@"Found Existing Thread with %d message(s). Updating it...", [thread messageCount]);
//        }
//		[thread setValue: [self valueForKey: @"date"] forKey: @"date"];
//
//		if (! [[thread valueForKey: @"subject"] length] && [[self valueForKey: @"subject"] length]) {
//			// If the thread does not yet have a proper subject, take the one from the first message thast does.
//			[thread setValue: [self valueForKey: @"subject"] forKey: @"subject"];
//		}
//		
//        // We got one, so set it:
//        [self setValue: thread forKey: @"thread"];
//    }
//    
//    return thread;
//}




- (NSString *)flagsString
	/*" Returns a textual representation of some flags. Used for exporting messages, including their flags. Not all available flags are supported. "*/
{
    char result[sizeof(unsigned) * 8 + 1];  // size of flags vector in bits + 1
    int i = 0;
    unsigned f = [self flags];
    
    if (f & OPInterestingStatus) result[i++] = 'I';
    if (f & OPAnsweredStatus)    result[i++] = 'A';
    if (f & OPJunkMailStatus)    result[i++] = 'J';
    if (f & OPSeenStatus)        result[i++] = 'R';
    //if (f & OPDraftStatus)       result[i++] = 'D';
    
    result[i++] = '\0'; // terminate string
    
    return [NSString stringWithCString:result];
}

- (NSString *)recipientsForDisplay
{
	NSString *result = [self valueForKey:@"to"];
	if ([result length] == 0)
	{
		result = [self.internetMessage toWithFallback:YES];
		
		// self repairing:
		if ([self hasFlags:OPIsFromMeStatus])
		{
			NSLog(@"repairing to field");
			[self setValue:result forKey:@"to"];
		}
	}
	
	if ([result rangeOfString:@","].length == 0) 
	{
		result = [result realnameFromEMailStringWithFallback];
	}
	
	return result;
}


- (void) addFlagsFromString: (NSString*) flagsString
	/*" Not all available flags are supported. "*/
{
    unsigned f = 0;
    
    int flagsCount = [flagsString length];
    for (int i = 0; i < flagsCount; i++) {
        unichar flagChar = [flagsString characterAtIndex:i];
        
        switch (flagChar) {
            case 'I': f |= OPInterestingStatus;
                      break;
            case 'A': f |= OPAnsweredStatus;
                      break;
            case 'J': f |= OPJunkMailStatus;
                      break;
            case 'R': f |= OPSeenStatus;
                      break;
//             case 'D': f |= OPDraftStatus;
//                       break;
            default: if (NSDebugEnabled) NSLog(@"Unknown flag character in flags string: '%C' (0x%X)", flagChar, flagChar);
        }
    }
    
    [self addFlags:f];
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

- (unsigned)sendStatus
{
	[self willAccessValueForKey:@"sendStatus"];
	id result = [self primitiveValueForKey:@"sendStatus"];
	[self didAccessValueForKey:@"sendStatus"];	
	unsigned intResult = [result intValue];
	//NSLog(@"SendStatus of %@ is %u", self, result);
	NSAssert2(intResult<=OPSendStatusSending, @"Illegal send status of %@: %@ detected.", self, result);
	NSAssert(intResult==0 || [self valueForKey: @"sendProfile"] !=nil, @"No profile set, but send status");
	return intResult;
}

- (void)setSendStatus:(unsigned)newStatus
{
	NSParameterAssert(newStatus<=OPSendStatusSending);
	[self willChangeValueForKey:@"sendStatus"];
	[self setPrimitiveValue: newStatus == 0 ? nil : [NSNumber numberWithInt: newStatus] forKey: @"sendStatus"];
	[self didChangeValueForKey:@"sendStatus"];
	//NSLog(@"SendStatus of %@ changed to %u", self, newStatus);
}

+ (NSMutableDictionary *)earliestSendTimes
{
	static NSMutableDictionary *earliestSendTimes = nil;
	
	if (!earliestSendTimes)
	{
		earliestSendTimes = [[[NSUserDefaults standardUserDefaults] objectForKey:EarliestSendTimes] mutableCopy];
		if (!earliestSendTimes) earliestSendTimes = [[NSMutableDictionary alloc] init];
	}
	
	return earliestSendTimes;
}

+ (void)repairEarliestSendTimes
{
	NSMutableDictionary *earliestSendTimes = [self earliestSendTimes];
	NSEnumerator *enumerator = [earliestSendTimes keyEnumerator];
	NSString *objectURL;
	OPPersistentObjectContext *context = [OPPersistentObjectContext defaultContext];
	NSMutableArray *badKeys = [NSMutableArray array];
	
	while (objectURL = [enumerator nextObject]) {
		if (![context objectWithURLString: objectURL]) {
			[badKeys addObject: objectURL];
		}
	}
	
	[earliestSendTimes removeObjectsForKeys:badKeys];
	[[NSUserDefaults standardUserDefaults] setObject:earliestSendTimes forKey:EarliestSendTimes];
}

- (NSDate *)earliestSendTime
{
	return [[[self class] earliestSendTimes] objectForKey:[self objectURLString]];
}

- (void)setEarliestSendTime:(NSDate *)aDate
{
	NSMutableDictionary *earliestSendTimes = [[self class] earliestSendTimes];
	
	if (aDate)
	{
		[earliestSendTimes setObject:aDate forKey:[self objectURLString]];
	}
	else
	{
		[earliestSendTimes removeObjectForKey:[self objectURLString]];
	}
	
	[[NSUserDefaults standardUserDefaults] setObject:earliestSendTimes forKey:EarliestSendTimes];
}

- (void)addFlags:(unsigned)someFlags
{
    NSNumber *oldValue = nil;
    NSNumber *newValue = nil;

    @synchronized(self) {
		someFlags = (0xffffffff ^ [self flags]) & someFlags;
//        if (someFlags) {
//			// Some flags actually changed!
//
//            // flags to set:
////#warning isInSendJob not in DB schema ignored.
//            //if ((someFlags & OPInSendJobStatus)) [self setValue: yes forKey: @"isInSendJob"]; // not in DB schema!?
////            if ((someFlags & OPQueuedStatus)) [self setValue: yes forKey: @"isQueued"];
//            if ((someFlags & OPInterestingStatus)) [self setValue: yesNumber forKey: @"isInteresting"];
//            if ((someFlags & OPSeenStatus)) [self setValue: yesNumber forKey: @"isSeen"];
//            if ((someFlags & OPJunkMailStatus)) [self setValue: yesNumber forKey: @"isJunk"];
////#warning isSendingBlocked not in DB schema ignored.
//            //if ((someFlags & OPSendingBlockedStatus)) [self setValue: yes forKey: @"isSendingBlocked"];
//            if ((someFlags & OPFlaggedStatus)) [self setValue: yesNumber forKey: @"isFlagged"];
//            if ((someFlags & OPIsFromMeStatus)) [self setValue: yesNumber forKey: @"isFromMe"];
//            if ((someFlags & OPFulltextIndexedStatus)) [self setValue: yesNumber forKey: @"isFulltextIndexed"];
//            if ((someFlags & OPAnsweredStatus)) [self setValue: yesNumber forKey: @"isAnswered"];
////            if ((someFlags & OPDraftStatus)) [self setValue: yes forKey: @"isDraft"];
//			
//            flagsCache = someFlags | flags;
//			oldValue = [NSNumber numberWithInt:flags];
//			newValue = [NSNumber numberWithInt:flagsCache];
//        }
    }
    
    // notify if needed (outside the synchronized block to avoid blocking problems)
    if (newValue) 
	{
        [[NSNotificationCenter defaultCenter] postNotificationName:GIMessageDidChangeFlagsNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys: oldValue, @"oldValue", newValue, @"newValue", nil, nil]];
		
		[[self thread] willChangeValueForKey:@"hasUnreadMessages"];
		[[self thread] didChangeValueForKey:@"hasUnreadMessages"];
    }    
}

/*
- (void) setValue: (id) value forKey: (NSString*) key
{
	[super setValue: value forKey: key];
}

 */

- (void) willSave
{
	NSLog(@"Will save %@", self);
	if (![self valueForKey: @"thread"]) {
		NSLog(@"Warning! Will save message without thread: %@", self);
	}
	NSString* transferDataPath = [self messageFilename];
	[self.internetMessage.transferData writeToFile: transferDataPath atomically: NO];
}


- (void) removeFlags: (unsigned) someFlags
{
	//    NSNumber* oldValue = nil;
	//    NSNumber* newValue = nil;
    
	// Setters lock the context to prevent updates during commit:
	@synchronized([self context]) {
		@synchronized(self) {
			flags = (flags & (~someFlags));
		}
	}
    
	//    // notify if needed (outside the synchronized block to avoid blocking problems)
	//    if (newValue) {
	//        [[NSNotificationCenter defaultCenter] postNotificationName:GIMessageDidChangeFlagsNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:oldValue, @"oldValue", newValue, @"newValue", nil, nil]];
	//		
	//		[[self thread] willChangeValueForKey:@"hasUnreadMessages"];
	//		[[self thread] didChangeValueForKey:@"hasUnreadMessages"];
	//    }
}

//- (GIMessage *)reference
///*" Returns the direct message reference stored. "*/
//{
//    [self willAccessValueForKey: @"reference"];
//    id reference = [self primitiveValueForKey: @"reference"];
//    [self didAccessValueForKey: @"reference"];
//    return reference;
//}

- (GIMessage*) referenceFind: (BOOL) find
/*" Returns the direct message reference stored.
    If there is none and find is YES, looks up the references header(s) in the
    internet message object and caches the result (if any).
    
    #ATTENTION: This method will generate dummy messages and add them to the 
    thread if required and %find is YES! "*/
{
    GIMessage* result = [self valueForKey: @"reference"];
    
    if (result || !find)
        return result;
     
#warning thread lookup disabled for now.
    //[GIThread addMessageToAppropriateThread:self];
    
    return [self valueForKey: @"reference"];
}        
        
- (BOOL) isListMessage
	/*" Returns YES, if Ginko thinks (from the message headers) that this message is from a mailing list (note, that a message can be both, a usenet article and an email). Decodes internet message to compute the result - so it may be slow! "*/
{
    id m = [self internetMessage];   
    
    // do more guesses here...
    return (([m bodyForHeaderField: @"List-Post"] != nil)
            || ([m bodyForHeaderField: @"List-Id"] != nil)
            || ([m bodyForHeaderField: @"X-List-Post"] != nil));
}


- (void) addOrderedSubthreadToArray: (NSMutableArray*) result
/*" Adds the receiver and all messages of this thread directly or indirectly referencing the receiver, sorted by tree. "*/
{
    [result addObject: self];
    [self comments]; // makes sure those are cached
    int i;
    int commentCount = [comments count];
    for (i=0; i<commentCount; i++) {
        [[comments objectAtIndex: i] addOrderedSubthreadToArray: result];
    }
} 

- (OPInternetMessage*) internetMessage
{
	if (!internetMessage) {

		NSString* transferDataPath = [self messageFilename];
		NSData* transferData = [NSData dataWithContentsOfFile: transferDataPath];
		internetMessage = [[OPInternetMessage alloc] initWithTransferData: transferData];
	}
	return internetMessage;
}

- (id) initWithCoder: (NSCoder*) coder
{
	messageId = [coder decodeObjectForKey: @"messageId"];
	subject = [coder decodeObjectForKey: @"subject"];
	to = [coder decodeObjectForKey: @"to"];
	date = [coder decodeObjectForKey: @"date"];
	senderName = [coder decodeObjectForKey: @"senderName"];
	sendProfileOID = [coder decodeOIDForKey: @"sendProfileOID"];
	threadOID = [coder decodeOIDForKey: @"threadOID"];
	referenceOID = [coder decodeOIDForKey: @"referenceOID"];
	flags = [coder decodeInt32ForKey: @"flags"];	
	return self;
}

- (void) encodeWithCoder: (NSCoder*) coder
{
	[coder encodeObject: messageId forKey: @"messageId"];
	[coder encodeObject: subject forKey: @"subject"];
	[coder encodeObject: to forKey: @"to"];
	[coder encodeObject: date forKey: @"date"];
	[coder encodeObject: senderName forKey: @"senderName"];
	[coder encodeInt32: flags forKey: @"flags"];

	[coder encodeOID: sendProfileOID forKey: @"sendProfileOID"];
	[coder encodeOID: threadOID forKey: @"threadOID"];
	[coder encodeOID: referenceOID forKey: @"referenceOID"];
}

@end


@implementation OPPersistentObjectContext (GIModelExtensions)

- (NSString*) transferDataDirectory
{
	static NSString* result = nil;
	if (result == nil) {
		result = [[NSHomeDirectory() stringByAppendingPathComponent: @"Library/Gina/TransferData/"] retain];
	}
	return result;
}

@end
