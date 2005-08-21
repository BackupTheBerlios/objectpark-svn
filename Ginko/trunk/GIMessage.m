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
#import "G3MessageGroup.h"
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
	@"author = {ColumnName = ZAUTHOR; AttributeClass = NSString;};"
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
    
    G3Message *dupe = [self messageForMessageId: [im messageId]];
    if (dupe)
    {
        if ([G3Profile isMyEmailAddress:[im fromWithFallback:YES]])
        {
            //replace old message with new:
            [GIMessageBase removeMessage:dupe];
            [NSApp saveAction:self];
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
        result = [[[G3Message alloc] initWithManagedObjectContext:[NSManagedObjectContext threadContext]] autorelease];
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
    G3Message* other;
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
        [thread addMessage: self];
    }
    
    return thread;
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
