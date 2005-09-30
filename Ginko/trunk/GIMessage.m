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
#import "NSManagedObjectContext+Extensions.h"
#import "OPInternetMessage+GinkoExtensions.h"
#import "OPManagedObject.h"
#import "GIMessageGroup.h"
#import "GIMessageBase.h"
#import "GIApplication.h"
#import "OPPersistentObject+Extensions.h"
#import <Foundation/NSDebug.h>

@implementation GIMessage

    // CREATE TABLE ZMESSAGE ( Z_ENT INTEGER, Z_PK INTEGER PRIMARY KEY, Z_OPT INTEGER, ZISANSWERED INTEGER, ZISFLAGGED INTEGER, ZMESSAGEID VARCHAR, ZISFULLTEXTINDEXED INTEGER, ZISSEEN INTEGER, ZISINTERESTING INTEGER, ZAUTHOR VARCHAR, ZISFROMME INTEGER, ZISDRAFT INTEGER, ZISQUEUED INTEGER, ZSUBJECT VARCHAR, ZDATE TIMESTAMP, ZISJUNK INTEGER, ZTHREAD INTEGER, ZPROFILE INTEGER, ZREFERENCE INTEGER, ZMESSAGEDATA INTEGER );

+ (NSString*) databaseTableName
{
    return @"ZMESSAGE";
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
	@"profile = {ColumnName = ZPROFILE; AttributeClass = GIProfile;};"
	@"thread = {ColumnName = ZTHREAD; AttributeClass = GIThread;};"
	@"}";
}


+ (id) messageForMessageId: (NSString*) messageId
	/*" Returns either nil or the message specified by its messageId. "*/
{
	GIMessage* result = nil;
    if (messageId) {
		
		OPPersistentObjectContext* context = [OPPersistentObjectContext defaultContext];
		
		OPPersistentObjectEnumerator* objectEnum = [context objectEnumeratorForClass: self where: @"$messageId=?"];
		
		[objectEnum reset]; // optional
		[objectEnum bind: messageId, nil]; // only necessary for requests containing question mark placeholders
		
		result = [objectEnum nextObject];
		[objectEnum reset]; // might free some memory.
		
	}
	return result;
}

- (void) flushInternetMessageCache
	/*" Flushes the cache for the internetMessageCache transient attribute. Used for optimized memory usage. "*/
{
    [self setPrimitiveValue: nil forKey: @"internetMessageCache"];
}

- (NSData*) transferData
{
	return [self valueForKeyPath: @"messageData.transferData"];
}

- (OPInternetMessage*) internetMessage
{
    OPInternetMessage* cache = [self primitiveValueForKey: @"internetMessageCache"];
    if (!cache) {
        NSData *transferData = [self valueForKey: @"transferData"];
        
        if (transferData) {
            cache = [[OPInternetMessage alloc] initWithTransferData: transferData];
            [self setPrimitiveValue: cache forKey: @"internetMessageCache"];
            [cache release];
        }
    } 
    //else NSLog(@"using cached imessage data"); // remove this after testing.
    return cache;
}

+ (id)messageWithTransferData: (NSData*) someTransferData
	/*" Returns a new message with the given transfer data someTransferData in the managed object context aContext. If message is a dupe, the message not inserted into the context nil is returned. "*/
{
    id result = nil;
    OPInternetMessage* im = [[OPInternetMessage alloc] initWithTransferData: someTransferData];
    BOOL insertMessage = NO;
    
    GIMessage *dupe = [self messageForMessageId: [im messageId]];
    if (dupe)
    {
        if ([GIProfile isMyEmailAddress: [im fromWithFallback:YES]])
        {
            //replace old message with new:
            [GIMessageBase removeMessage: dupe];
            [NSApp saveAction: self];
            insertMessage = YES;
        }
        //if (NSDebugEnabled) NSLog(@"Dupe for message id %@ detected.", [im messageId]);        
    } 
    else
    {
        insertMessage = YES;
    }
    
    if (insertMessage)
    {
        // Create a new message in the default context:
        result = [[[GIMessage alloc] initWithManagedObjectContext:[NSManagedObjectContext threadContext]] autorelease];
        NSAssert(result != nil, @"Could not create message object");
        
        NSString *fromHeader = [im fromWithFallback: YES];
        
        [result setPrimitiveValue:im forKey:@"internetMessageCache"];
        [result setValue:someTransferData forKey:@"transferData"];
        [result setValue:[im messageId] forKey:@"messageId"];  
        [result setValue:[im normalizedSubject] forKey:@"subject"];
        [result setValue:[fromHeader realnameFromEMailStringWithFallback] forKey:@"author"];
        
        // sanity check for date header field:
        NSCalendarDate *messageDate = [im date];
        if ([(NSDate *)[NSDate dateWithTimeIntervalSinceNow:15 * 60.0] compare:messageDate] != NSOrderedDescending) // if message's date is a future date
        {
			// broken message, set current date:
            messageDate = [NSCalendarDate date];
            if (NSDebugEnabled) NSLog(@"Found message with future date. Fixing broken date with 'now'.");
        }
        [result setValue:messageDate forKey:@"date"];
        
        // Note that this method operates on the encoded header field. It's OK because email
        // addresses are 7bit only.
        if ([GIProfile isMyEmailAddress:fromHeader]) {
            [result addFlags: OPIsFromMeStatus];
        }
    }
    
    [im release];
    return result;
}

- (BOOL) isUsenetMessage
	/*" Returns YES, if Ginko thinks (from the message headers) that this message is an Usenet News article (note, that a message can be both, a usenet article and an email). This message causes the message to be decoded. "*/
{
    return ([[self internetMessage] bodyForHeaderField:@"Newsgroups"] != nil);
}

- (BOOL) isEMailMessage
	/*" Returns YES, if Ginko thinks (from the message headers) that this message is some kind of email (note, that a message can be both, a usenet article and an email). This message causes the message to be decoded. "*/
{
    return ([[self internetMessage] bodyForHeaderField:@"To"] != nil);
}

- (BOOL) isPublicMessage 
{
    return [self isListMessage] || [self isUsenetMessage];
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

            if ([self primitiveBoolForKey: @"isInSendJob"]) flagsCache |= OPInSendJobStatus;
            if ([self primitiveBoolForKey: @"isQueued"]) flagsCache |= OPQueuedStatus;
            if ([self primitiveBoolForKey: @"isInteresting"]) flagsCache |= OPInterestingStatus;
            if ([self primitiveBoolForKey: @"isSeen"]) flagsCache |= OPSeenStatus;
            if ([self primitiveBoolForKey: @"isJunk"]) flagsCache |= OPJunkMailStatus;
            if ([self primitiveBoolForKey: @"isSendingBlocked"]) flagsCache |= OPSendingBlockedStatus;
			if ([self primitiveBoolForKey: @"isFlagged"]) flagsCache |= OPFlaggedStatus;
			if ([self primitiveBoolForKey: @"isFromMe"]) flagsCache |= OPIsFromMeStatus;
            if ([self primitiveBoolForKey: @"isFulltextIndexed"]) flagsCache |= OPFulltextIndexedStatus;
            if ([self primitiveBoolForKey: @"isAnswered"]) flagsCache |= OPAnsweredStatus;
            if ([self primitiveBoolForKey: @"isDraft"]) flagsCache |= OPDraftStatus;
			
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
    [self setValue: cachedValue forKey: @"numberOfReferences"];
    return [cachedValue unsignedIntValue];
}

- (NSArray*) commentsInThread: (GIThread*) thread
	/* Returns all directly commenting messages in the thread given. */
{
    NSEnumerator* me = [[thread messages] objectEnumerator];
    NSMutableArray *result = [NSMutableArray array];
    GIMessage* other;
    while (other = [me nextObject]) {
        if ([other reference] == self) {
            [result addObject: other];
        }
    }
    return result;
}

- (NSAttributedString *)contentAsAttributedString
{
    return [[self internetMessage] bodyContent];
}


- (GIThread*) threadCreate: (BOOL) doCreate
	/*" Returns the one thread the message belongs to. If doCreate is yes, this method creates a new thread in the receiver's context containing just the receiver. "*/
{
    GIThread *thread = [self thread];
    
    if (doCreate && !thread) {
        // do threading by reference
        thread = [[self referenceFind: YES] thread];
        
        if (!thread) {
            thread = [[[GIThread alloc] init] autorelease];
			[thread insertIntoContext: [self context]];
            [thread setValue: [self valueForKey: @"subject"] forKey: @"subject"];
        } else {
            // NSLog(@"Found Existing Thread with %d message(s). Updating it...", [thread messageCount]);
            // Set the thread's subject to be the first messages subject:
        }
        // We got one, so set it:
        [self setValue: thread forKey: @"thread"];
        [thread addToMessages: self];
    }
    
    return thread;
}

- (NSString*) senderName
	/*" Returns the real name extracted from the 'From' header. "*/
{
	[self willAccessValueForKey: @"senderName"];
    NSString* result = [self valueForKey: @"senderName"];
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
    char result[10]; 
    int i = 0;
    //NSMutableString* result = [[[NSMutableString alloc] initWithCapacity: 6] autorelease];
    unsigned flags = [self flags];
    if (flags & OPInterestingStatus) result[i++] = 'I';
    if (flags & OPAnsweredStatus) result[i++] = 'A';
    if (flags & OPJunkMailStatus) result[i++] = 'J';
    if (flags & OPSeenStatus) result[i++] = 'R';
    if (flags & OPDraftStatus) result[i++] = 'D';
    result[i++] = '\0'; // terminate string
    return [NSString stringWithCString:result];
}

- (void) addFlagsFromString: (NSString*) flagsString
	/*" Not all available flags are supported. "*/
{
    char flagcstr[20];
    unsigned flags = 0;
    [flagsString getCString:flagcstr maxLength:19];
    if (strchr(flagcstr, 'I')) flags |= OPInterestingStatus;
    if (strchr(flagcstr, 'A')) flags |= OPAnsweredStatus;
    if (strchr(flagcstr, 'J')) flags |= OPJunkMailStatus;
    if (strchr(flagcstr, 'R')) flags |= OPSeenStatus;
    if (strchr(flagcstr, 'D')) flags |= OPDraftStatus;
    [self addFlags:flags];
}

- (BOOL)hasFlags:(unsigned)someFlags
{
    return (someFlags & [self flags]) == someFlags;
}

- (void)addFlags:(unsigned)someFlags
{
    @synchronized(self)
    {
        int flags = [self flags];
        if (someFlags | flags != flags)
        {
            // flags to set:
            NSNumber *yes = [NSNumber numberWithBool:YES];
            if (someFlags & OPInSendJobStatus) [self setValue:yes forKey:@"isInSendJob"];
            if (someFlags & OPQueuedStatus) [self setValue:yes forKey:@"isQueued"];
            if (someFlags & OPInterestingStatus) [self setValue:yes forKey:@"isInteresting"];
            if (someFlags & OPSeenStatus) [self setValue:yes forKey:@"isSeen"];
            if (someFlags & OPJunkMailStatus) [self setValue:yes forKey:@"isJunk"];
            if (someFlags & OPSendingBlockedStatus) [self setValue:yes forKey:@"isSendingBlocked"];
            if (someFlags & OPFlaggedStatus) [self setValue:yes forKey:@"isFlagged"];
            if (someFlags & OPIsFromMeStatus) [self setValue:yes forKey:@"isFromMe"];
            if (someFlags & OPFulltextIndexedStatus) [self setValue:yes forKey:@"isFulltextIndexed"];
            if (someFlags & OPAnsweredStatus) [self setValue:yes forKey:@"isAnswered"];
            if (someFlags & OPDraftStatus) [self setValue:yes forKey:@"isDraft"];
			
            flagsCache = someFlags | flags;
        }
    }
}

- (void)removeFlags:(unsigned)someFlags
{
    @synchronized(self)
    {
        int flags = [self flags];
        
        if ((flags & (~someFlags)) != flags)
        {
            // flags to remove:
            NSNumber *no = [NSNumber numberWithBool:NO];
            if (someFlags & OPInSendJobStatus) [self setValue:no forKey:@"isInSendJob"];
            if (someFlags & OPQueuedStatus) [self setValue:no forKey:@"isQueued"];
            if (someFlags & OPInterestingStatus) [self setValue:no forKey:@"isInteresting"];
            if (someFlags & OPSeenStatus) [self setValue:no forKey:@"isSeen"];
            if (someFlags & OPJunkMailStatus) [self setValue:no forKey:@"isJunk"];
            if (someFlags & OPSendingBlockedStatus) [self setValue:no forKey:@"isSendingBlocked"];
            if (someFlags & OPFlaggedStatus) [self setValue:no forKey:@"isFlagged"];
            if (someFlags & OPIsFromMeStatus) [self setValue:no forKey:@"isFromMe"];
            if (someFlags & OPFulltextIndexedStatus) [self setValue:no forKey:@"isFulltextIndexed"];
            if (someFlags & OPAnsweredStatus) [self setValue:no forKey:@"isAnswered"];
            if (someFlags & OPDraftStatus) [self setValue:no forKey:@"isDraft"];
            
            flagsCache = (flags & (~someFlags));
        }
    }
}

- (GIMessage*) reference
/*" Returns the direct message reference stored. "*/
{
    [self willAccessValueForKey:@"reference"];
    id reference = [self primitiveValueForKey:@"reference"];
    [self didAccessValueForKey:@"reference"];
    return reference;
}

- (GIMessage*) referenceFind: (BOOL) find
/*" Returns the direct message reference stored. If there is none and find is YES, looks up the references header(s) in the internet message object and caches the result (if any). "*/
{
    GIMessage *result = [self reference];
    if (!result && find) {
        NSEnumerator* e = [[[self internetMessage] references] reverseObjectEnumerator];
        NSString *refId;
        while (refId = [e nextObject]) {
			
            if (result = [[self class] messageForMessageId: refId]) {
                [self setValue: result forKey: @"reference"];
                return result;
            }
        }
    }
    return nil;
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

- (void) setSendJobStatus
{
    [self addFlags: OPInSendJobStatus];
}

- (void) resetSendJobStatus
{
    [self removeFlags: OPInSendJobStatus];
}

@end

@implementation GIMessageData

+ (NSString*) databaseTableName
{
    return @"ZMESSAGEDATA";
}

+ (NSString*) persistentAttributesPlist
{
	return 
	@"{"
	@"transferData = {ColumnName = ZTRANSFERDATA; AttributeClass = NSData;};"
	@"}";
}

@end
