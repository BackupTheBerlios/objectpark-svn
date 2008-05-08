//
//  GIMessage.m
//  Gina
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
#import "OPInternetMessage+GinkoExtensions.h"
#import "GIMessageGroup.h"
#import "GIMessageBase.h"
#import "GIApplication.h"
#import "OPPersistentObjectContext.h"
#import <Foundation/NSDebug.h>
#import "NSApplication+OPExtensions.h"
#import "GIUserDefaultsKeys.h"
#import "EDMessagePart+OPExtensions.h"
#import "OPPersistentStringDictionary.h"

NSString *GIMessageDidChangeFlagsNotification = @"GIMessageDidChangeFlagsNotification";

#define MESSAGE           OPL_DOMAIN  @"Message"
#define DUPECHECK         OPL_ASPECT  0x01
#define FLAGS             OPL_ASPECT  0x02
#define DUMMYCREATION     OPL_ASPECT  0x04
#define MESSAGEREPLACING  OPL_ASPECT  0x08



@implementation GIMessage

@synthesize to;
@synthesize date;
@synthesize unreadMessageCount;
@synthesize subject;

- (void) clearCommentsCache
{
	[comments release]; comments = nil;
}

- (GIThread *)thread
{
	return [[self context] objectForOID:threadOID];
}

- (void) setThread: (GIThread*) aThread
{
	if (threadOID != [aThread oid]) {
		[self willChangeValueForKey:@"thread"];

		if (threadOID) {
			[[self.thread mutableArrayValueForKey:@"messages"] removeObjectIdenticalTo: self];
		}
		[self.reference clearCommentsCache];
		threadOID = [aThread oid];
		[[aThread mutableArrayValueForKey:@"messages"] addObject:self];
		[self didChangeValueForKey:@"thread"];
	}
}


//+ (void) context: (OPPersistentObjectContext*) context willDeleteInstanceWithOID: (OID) oid
//{
//	
//	
//	//[[context objectForOID: oid] willDelete]; // loads instance (slow)
//	
//	// Optimization:
//	
//	[[NSFileManager defaultManager] removeFileAtPath: [self messageFilePathForOID: oid inContext: context] handler: nil];
//	
//	[[[self context] messagesByMessageId] removeObjectForKey:self.messageId];
//	
//	// remove from any profiles:
//	GIProfile *sendProfile = [GIProfile sendProfileForMessage:self];
//	if (sendProfile) 
//	{
//		[[sendProfile mutableArrayValueForKey:@"messagesToSend"] removeObject:self];
//		NSLog(@"removing message %@ from sendProfile %@", self, sendProfile);
//	}
//}


- (void)willDelete
{
//	id thread = self.thread;
//	if (thread) 
//	{
//		self.thread = nil;
//		
//		if ([thread messageCount] <= 1) 
//		{
//			[thread delete]; 
//		}
//	}
	
	[[NSFileManager defaultManager] removeFileAtPath:self.messageFilePath handler:nil];
	
	[[[self context] messagesByMessageId] removeObjectForKey:self.messageId];
	
	// remove from any profiles:
	GIProfile *sendProfile = [GIProfile sendProfileForMessage:self];
	if (sendProfile) 
	{
		[[sendProfile mutableArrayValueForKey:@"messagesToSend"] removeObject: self];
		NSLog(@"removing message %@ from sendProfile %@", self, sendProfile);
	}
	
	[super willDelete];
}

+ (NSString*) messageFilePathForOID: (OID) oid
						  inContext: (OPPersistentObjectContext*) context
{
	NSString *filename = [[context transferDataDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"Msg%014llx.gml", LIDFromOID(oid)]];
	return filename;
}

- (NSString *)messageFilePath
{
	return [[self class] messageFilePathForOID: self.oid inContext: self.context];
}

- (NSString *)senderName
{
	return senderName;
}


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
    
	NSParameterAssert(aMessageId);
	
    // if there already is a message with that id we'll use that
	// This may not be dummy! So what happens then?
    if (dummy = [[OPPersistentObjectContext defaultContext] messageForMessageId: aMessageId])
        return dummy;
        
    if (NSDebugEnabled) NSLog(@"creating dummy message for message id %@", aMessageId);
    
    dummy = [[[GIMessage alloc] initDummy] autorelease];
    //[dummy insertIntoContext: [OPPersistentObjectContext threadContext]]; 
    NSAssert(dummy != nil, @"Could not create a dummy message object");

    [dummy setValue:aMessageId forKey:@"messageId"];  
    
	NSAssert([dummy isDummy], @"Dummy message not marked as such");
	
	[[[OPPersistentObjectContext defaultContext] messagesByMessageId] setValue: dummy forKey: aMessageId];  
	
    return dummy;
}

- (void)setContentFromInternetMessage:(OPInternetMessage *)im appendToAppropriateThread:(BOOL)doThread forcedMessageId:(NSString *)forcedMessageId
/*" Does not set the reference ivar. "*/
{
	NSParameterAssert(im != nil);
	
    NSString *fromHeader = [im fromWithFallback:YES];
    
	[self toggleFlags:flags & OPDummyStatus]; // remove Dummy status
	[self toggleFlags:flags & OPSeenStatus]; // remove read status
	
	[internetMessage release];
	internetMessage = [im retain];
	messageId = forcedMessageId.length ? forcedMessageId : [[im messageId] retain];
	
	// Add self to global message id index:
	if (messageId.length) {
		[[[OPPersistentObjectContext defaultContext] messagesByMessageId] setObject:self forKey:messageId];  
	}
	
    [subject release]; subject = [[im normalizedSubject] copy];
    [self setValue:[fromHeader realnameFromEMailStringWithFallback] forKey:@"senderName"];
    
    // sanity check for date header field:
    [date release]; date = [[NSDate alloc] initWithTimeIntervalSinceReferenceDate:[[im date] timeIntervalSinceReferenceDate]];
    if ([(NSDate *)[NSDate dateWithTimeIntervalSinceNow:15 * 60.0] compare: date] != NSOrderedDescending) {
        // if message's date is a future date
        // broken message, set current date:
		[date release]; date = [[NSDate date] retain];
		if (NSDebugEnabled) NSLog(@"Found message with future date. Fixing broken date with 'now'.");
    }
    
    // Note that this method operates on the encoded header field. It's OK because email
    // addresses are 7bit only.
    if ([GIProfile isMyEmailAddress: fromHeader]) {
        [self toggleFlags: flags ^ (OPIsFromMeStatus | OPSeenStatus)]; // never changes, hopefully
    }
	
	// Setting thread:
	GIThread *thread = self.thread;
	GIMessage *referencingMsg = self;
	GIMessage *referencedMsg = nil;
	BOOL didCreateDummy = NO;

	if (doThread)
	{
		NSMutableArray *references = [NSMutableArray arrayWithArray:[im references]];
		[references removeObject:messageId];  // no self referencing allowed

		// Find the appropriate thread by walking the references list:
		NSString *refId;
		while (refId = [references lastObject]) 
		{
			referencedMsg = [[self context] messageForMessageId:refId];
			
			if (referencedMsg) 
			{
				if (NSDebugEnabled) NSLog(@"%@ (%qu) -> %@ (%qu)", referencingMsg.messageId, referencingMsg.oid, referencedMsg.messageId, referencedMsg.oid);
				referencingMsg.reference = referencedMsg; // create message chain
				
				if (!thread) thread = referencedMsg.thread;
				[thread mergeMessagesFromThread:referencedMsg.thread]; // usually does nothing as thread == referencedMsg.thread
			} 
			else 
			{
				// create dummy message for refId:
				referencedMsg = [GIMessage dummyMessageWithId:refId andDate:self.date];
				didCreateDummy = YES;
			}
			// referencedMsg is now set.
			
			
			if (NSDebugEnabled) NSLog(@"%@ (%qu) -> %@ (%qu)", referencingMsg.messageId, referencingMsg.oid, referencedMsg.messageId, referencedMsg.oid);
			referencingMsg.reference = referencedMsg;
			
			referencingMsg = referencedMsg;
			[references removeLastObject];
			[references removeObject:refId]; // buggy messages can have circles in their references
		}
	}
	
	if (! thread) 
	{
		// create a new thread:
		thread = [[GIThread alloc] init];
		thread.subject = subject;
		thread.date = date;
	}
	
	// Make sure, all messages have the same thread set:
	referencingMsg = self;	
	referencingMsg.thread = thread;
	
	if (didCreateDummy) 
	{
		// Make sure, all referenced messages, esp the dummies have the same thread set:
		int refCounter = 1000; // stop after 1000 hops => probably a circle.
		while (refCounter > 0 && (referencedMsg = referencingMsg.reference)) 
		{
			referencedMsg.thread = thread;
			referencingMsg = referencedMsg;
			refCounter -= 1;
		}
	}
}

- (BOOL)isSimilarToInternetMessage:(OPInternetMessage *)otherInternetMessage
{
	// first cheap to compare fields:
	if (![self.messageId isEqualToString:[otherInternetMessage messageId]]) return NO;
	if (![self.date isEqualToDate:[otherInternetMessage date]]) return NO;
	
	// now expensive to compare fields:
	OPInternetMessage *im = self.internetMessage;
	if (![[im subject] isEqualToString:[otherInternetMessage subject]]) return NO;
	if (![[im fromWithFallback:YES] isEqualToString:[otherInternetMessage fromWithFallback:YES]]) return NO;
	if (![[im toWithFallback:YES] isEqualToString:[otherInternetMessage toWithFallback:YES]]) return NO;
	if (![[im ccWithFallback:YES] isEqualToString:[otherInternetMessage ccWithFallback:YES]]) return NO;
	
	// now most expensive compare:
	if (![[im contentData] isEqualToData:[otherInternetMessage contentData]]) return NO;
	
	return YES;
}

/*" Returns a new message with the internetmessage object.
 If message is a dupe, the message not inserted into the context nil is returned. "*/
+ (id)messageWithInternetMessage:(OPInternetMessage *)anInternetMessage appendToAppropriateThread:(BOOL)doThread
{
    id result = nil;
	
    GIMessage *dupe = [[OPPersistentObjectContext defaultContext] messageForMessageId:[anInternetMessage messageId]];
	if (dupe)
	{
        if ([dupe isDummy] || 
			([anInternetMessage isResentMessage] && [dupe isSimilarToInternetMessage:anInternetMessage]))
		{
            // replace message
			if (NSDebugEnabled) NSLog(@"Replacing content for (dummy/resent) message with oid %qu (msgId: %@)", [dupe oid], [anInternetMessage messageId]);
            [dupe setContentFromInternetMessage:anInternetMessage appendToAppropriateThread:doThread forcedMessageId:nil];
            //[dupe referenceFind:YES];
        } 
		else if ([GIProfile isMyEmailAddress:[anInternetMessage fromWithFallback:YES]])
		{
            // replace old message with new:
			if (NSDebugEnabled) NSLog(@"Replacing content for own message with oid %qu (msgId: %@)", [dupe oid], [anInternetMessage messageId]);
            [dupe setContentFromInternetMessage:anInternetMessage appendToAppropriateThread:doThread forcedMessageId:nil];
        } 
		else
		{
			if (NSDebugEnabled) NSLog(@"Dupe for message id %@ detected. Ignoring.", [anInternetMessage messageId]);    
		}
		result = dupe;
    }
	else
	{
        // Create a new message in the default context:
        result = [[[GIMessage alloc] initWithInternetMessage:anInternetMessage appendToAppropriateThread:doThread forcedMessageId:nil] autorelease];
		NSAssert(result != nil, @"Could not create message object");
    }
    
    return result;
}

/*" Returns a new message with the internetmessage object.
 If message is a dupe, the message not inserted into the context nil is returned. "*/
- (id)initWithInternetMessage:(OPInternetMessage *)anInternetMessage appendToAppropriateThread:(BOOL)doThread forcedMessageId:(NSString *)forcedMessageId
{
    if (self = [super init]) {
		// Create a new message in the default context:
		referenceCount = NSNotFound;
        [self setContentFromInternetMessage:anInternetMessage appendToAppropriateThread:doThread forcedMessageId:forcedMessageId]; // also retains anInternetMessage
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

- (id)initDummy
{
	self = [super init];
	flags = OPDummyStatus | OPSeenStatus;
	return self;
}

- (BOOL)isDummy
{
    return (flags & OPDummyStatus) != 0;
}

- (void)setIsDummy:(BOOL)boolValue
{
	if (self.isDummy != boolValue) 
	{
		[self willChangeValueForKey:@"isDummy"];
		[self toggleFlags:OPDummyStatus];
		[self didChangeValueForKey:@"isDummy"];
	}
}

- (BOOL)isSeen
{
	return (flags & OPSeenStatus) != 0;
}

- (void)setIsSeen:(BOOL)boolValue
{
	if (self.isSeen == boolValue) return;
	if ([self isDummy]) return;

	[self willChangeValueForKey:@"isSeen"];
	[self toggleFlags:OPSeenStatus];
	[self didChangeValueForKey:@"isSeen"];
}

- (unsigned)flags
{
    return flags;
}

- (NSString *)messageId
{
	return [[messageId retain] autorelease];
}

/*" Returns the number of referenced messages until a root message is reached. "*/
- (unsigned) numberOfReferences
{
    if (referenceCount == NSNotFound) {
		referenceCount = [[self reference] numberOfReferences]+1;
    }
	return referenceCount;
}

- (void) flushNumberOfReferencesCache
{
	referenceCount = NSNotFound;
}

- (NSMutableArray*) commentsInThread: (GIThread*) aThread
	/* Returns all directly commenting messages in the thread given as a new autorleased mutable array. */
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
	static NSArray *descriptors = nil;
	if (! descriptors)
	{
		descriptors = [[NSArray alloc] initWithObjects:[[[NSSortDescriptor alloc] initWithKey:@"date" ascending:YES] autorelease], nil];
	}
	
	if (!comments) {
		NSMutableArray* newComments = [self commentsInThread: self.thread]; 
		if (newComments.count > 1) {
			[newComments sortUsingDescriptors:descriptors];
		}
		comments = [newComments retain];
	}
	return comments;
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
	[self clearCommentsCache];
	[internetMessage release]; internetMessage = nil;
	[super dealloc];
}


- (NSString*) description
{
	return [NSString stringWithFormat: @"%@ msgId %@, %@, flags %@", super.description, self.messageId, self.date, self.flagsString];
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
//    GIThread* result = self.thread;
//    
//	if (!result) {
//		if (useExisting) {
//			// do threading by reference
//			result = [[self referenceFind: YES] thread];
//        }
//		if (!result) {
//            result = [[[GIThread alloc] init] autorelease];
//			// Set the thread's subject to be the first message's subject:
//            result.subject = self.subject;
//        } else {
//             if (NSDebugEnabled) NSLog(@"Found Existing Thread with %d message(s). Updating it...", [result messageCount]);
//        }
//		result.date = self.date; 
//
//		if ((! [result.subject length]) && [self.subject length]) {
//			// If the thread does not yet have a proper subject, take the one from the first message thast does.
//			result.subject = self.subject;
//		}
//		
//        // We got one, so set it:
//        self.thread = result;
//    }
//    
//    return result;
//}
//
//


- (NSString *)flagsString
	/*" Returns a textual representation of some flags. Used for exporting messages, including their flags. Not all available flags are supported. "*/
{
    char result[sizeof(unsigned) * 8 + 1];  // size of flags vector in bits + 1
    int i = 0;
    unsigned f = [self flags];
    
	if (f & OPDummyStatus)       result[i++] = '?';
    if (f & OPInterestingStatus) result[i++] = 'I';
    if (f & OPAnsweredStatus)    result[i++] = 'A';
    if (f & OPJunkMailStatus)    result[i++] = 'J';
    if (f & OPSeenStatus)        result[i++] = 'R';
    
    result[i++] = '\0'; // terminate string
    
    return [NSString stringWithCString:result];
}

- (void)setTo:(NSString *)aString
{
	[self willChangeValueForKey:@"to"];
	[to autorelease];
	to = [aString retain];
	[self didChangeValueForKey:@"to"];
}

- (NSString *)recipientsForDisplay
{
	NSString *result = self.to;
	
	if ([result length] == 0)
	{
		result = [self.internetMessage toWithFallback:YES];
		
		// self repairing:
		if ([self hasFlags: OPIsFromMeStatus])
		{
			NSLog(@"repairing to field");
			[self setTo:result];
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
    
    [self toggleFlags: f & ~flags];
}


- (BOOL) hasFlags: (unsigned) someFlags
{
    return (someFlags & self.flags) == someFlags;
}

//+ (void) resetSendStatus
///*" Run during startup to set the sendStatus of OPSendStatusSending or OPSendStatusQueuedBlocked back to OPSendStatusQueuedReady "*/
//{
//	NSString* command = @"update ZMESSAGE set ZISQUEUED=3 where ZISQUEUED=2 or ZISQUEUED=4;";
//	[[[OPPersistentObjectContext defaultContext] databaseConnection] performCommand: command];
//}

- (unsigned)sendStatus
{
	NSAssert2(sendStatus<=OPSendStatusSending, @"Illegal send status of %@: %@ detected.", self, sendStatus);
//	NSAssert(sendStatus == 0 || [[self sendProfile] != nil, @"No profile set, but send status");
	return sendStatus;
}

- (void)setSendStatus:(unsigned)newStatus
{
	NSParameterAssert(newStatus <= OPSendStatusSending);
	
	[self willChangeValueForKey:@"sendStatus"];
	sendStatus = newStatus;
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

- (void) toggleFlags: (unsigned) someFlags
/*" Inverts the flags given. "*/
{
	if (!someFlags) return;

	[self willChangeValueForKey: @"flags"];
	flags ^= someFlags;
	[self didChangeValueForKey: @"flags"];
	
	[self.thread didToggleFlags: someFlags ofContainedMessage: self];
}

- (void)willSave
{
	//NSLog(@"Will save %@", self);
	if (!self.thread) 
	{
		NSLog(@"Warning! Will save message without thread: %@", self);
	}
	
	if (! [self isDummy])
	{
		NSString* transferDataPath = [self messageFilePath];
		if (! [[NSFileManager defaultManager] fileExistsAtPath: transferDataPath]) {
			if (! internetMessage) {
				NSLog(@"Warning! TransferDataFile at %@ not available on save.", transferDataPath);
			}
			[self.internetMessage.transferData writeToFile: transferDataPath atomically: NO];
		}
		[self flushInternetMessageCache]; // free some memory
	}
}




- (GIMessage *)reference
/*" Returns the direct message reference stored. "*/
{
	return [self.context objectForOID: referenceOID];
}

- (void) setReference: (GIMessage*) aReferencedMessage
{
	if (aReferencedMessage.oid != referenceOID) {
		[self willChangeValueForKey:@"reference"];
		referenceOID = aReferencedMessage.oid;
		[aReferencedMessage clearCommentsCache];
		[self didChangeValueForKey:@"reference"];
	}
}

/*" Returns the direct message reference stored.
 If there is none and find is YES, looks up the references header(s) in the
 internet message object and caches the result (if any).
 
 #ATTENTION: This method will generate dummy messages and add them to the 
 thread if required and %find is YES! "*/
//- (GIMessage *)referenceFind:(BOOL)find
//{
//    GIMessage *result = self.reference;
//    
//    if (result || !find)
//        return result;
//     
//    [GIThread addMessageToAppropriateThread:self];
//    
//    return self.reference;
//}        


        
/*" Returns YES, if Ginko thinks (from the message headers) that this message is from a mailing list (note, that a message can be both, a usenet article and an email). Decodes internet message to compute the result - so it may be slow! "*/
- (BOOL)isListMessage
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
//    [self comments]; // makes sure those are cached
//    int i;
//    int commentCount = [comments count];
	for (GIMessage* comment in [self comments]) {
		[comment addOrderedSubthreadToArray: result];
	}
	
//    for (i=0; i<commentCount; i++) {
//        [[comments objectAtIndex: i] addOrderedSubthreadToArray: result];
//    }
} 

- (OPInternetMessage*) internetMessage
{
	@synchronized(self) {
		if (!internetMessage) {
			
			NSString* transferDataPath = [self messageFilePath];
			NSData* transferData = [NSData dataWithContentsOfFile: transferDataPath];
			if (transferData) {
				internetMessage = [[OPInternetMessage alloc] initWithTransferData: transferData];
			} // else return nil
		}
		[internetMessage retain];
	}
	return [internetMessage autorelease];
}

- (void) flushInternetMessageCache
{
	[internetMessage release]; internetMessage = nil;
}

- (id)initWithCoder:(NSCoder *)coder
{
	messageId = [[coder decodeObjectForKey:@"messageId"] retain];
	subject = [[coder decodeObjectForKey:@"subject"] retain];
	to = [[coder decodeObjectForKey:@"to"] retain];
	date = [[coder decodeObjectForKey:@"date"] retain];
	senderName = [[coder decodeObjectForKey:@"senderName"] retain];
	threadOID = [coder decodeOIDForKey:@"threadOID"];
	referenceOID = [coder decodeOIDForKey:@"referenceOID"];
	flags = [coder decodeInt32ForKey:@"flags"];	
	unreadMessageCount = [coder decodeInt32ForKey:@"unreadMessageCount"];	
	referenceCount = NSNotFound;
	sendStatus = [coder decodeInt32ForKey:@"sendStatus"];
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:messageId forKey:@"messageId"];
	[coder encodeObject:subject forKey:@"subject"];
	[coder encodeObject:to forKey:@"to"];
	[coder encodeObject:date forKey:@"date"];
	[coder encodeObject:senderName forKey:@"senderName"];
	[coder encodeInt32:flags forKey:@"flags"];
	[coder encodeInt32:unreadMessageCount forKey:@"unreadMessageCount"];
	[coder encodeInt32:sendStatus forKey:@"sendStatus"];
	[coder encodeOID:threadOID forKey:@"threadOID"];
	[coder encodeOID:referenceOID forKey:@"referenceOID"];
}

@end

