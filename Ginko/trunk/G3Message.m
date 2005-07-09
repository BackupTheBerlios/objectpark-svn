//
//  G3Message.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 01.12.04.
//  Copyright 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "G3Message.h"
#import "G3Thread.h"
#import "G3Profile.h"
#import "OPInternetMessage.h"
#import "NSString+MessageUtils.h"
#import "NSManagedObjectContext+Extensions.h"
#import "OPInternetMessage+GinkoExtensions.h"
#import "OPManagedObject.h"
#import "G3MessageGroup.h"
#import <Foundation/NSDebug.h>

@class NSEntityDescription;

NSString *GIDupeMessageException = @"GIDupeMessageException";

@implementation G3Message

+ (id)messageForMessageId:(NSString *)messageId
/*" Returns either nil or the message specified by its messageId. "*/
{
    if (messageId)
    {
        NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
        //NSManagedObjectModel *model = [[NSApp delegate] managedObjectModel];
        [request setEntity: [self entity]];
        NSPredicate *predicate = [NSComparisonPredicate predicateWithLeftExpression:[NSExpression expressionForKeyPath: @"messageId"] rightExpression:[NSExpression expressionForConstantValue:messageId] modifier:NSDirectPredicateModifier type:NSEqualToPredicateOperatorType options:0];
        [request setPredicate:predicate];
        
        NSError *error = nil;
        NSArray *results = [[NSManagedObjectContext defaultContext] executeFetchRequest:request error:&error];
        
        NSAssert1(!error, @"+[G3Message messageForMessageId:inManagedObjectContext:] error while fetching (%@).", error);    
        
        if (results != nil) 
        {
            return [results count] ? [results lastObject] : nil;						
        } 
    }
    return nil;
}

/*
- (void) setInternetMessage: (OPInternetMessage *)iMessage
    //" Private method. Used for simplified memory management only. "
{
    [iMessage retain];
    [internetMessageCache release]; 
    internetMessageCache = iMessage;
}
*/

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


+ (id)messageWithTransferData:(NSData *)someTransferData
/*" Returns a new message with the given transfer data someTransferData in the managed object context aContext. If message is a dupe, the message not inserted into the context nil is returned. "*/
{
    id result = nil;
    OPInternetMessage* im = [[OPInternetMessage alloc] initWithTransferData: someTransferData];
    
    if ([self messageForMessageId: [im messageId]])
    {
        //if (NSDebugEnabled) NSLog(@"Dupe for message id %@ detected.", [im messageId]);        
    } else {
        
        // Create a new message in the default context:
        result = [[[G3Message alloc] initWithManagedObjectContext: [NSManagedObjectContext defaultContext]] autorelease];
        NSAssert(result != nil, @"Could not create message object");
        
        NSString *fromHeader = [im fromWithFallback: YES];
        
        [result setPrimitiveValue: im forKey: @"internetMessageCache"];
        [result setValue: someTransferData forKey: @"transferData"];
        [result setValue: [im messageId] forKey: @"messageId"];  
        [result setValue: [im normalizedSubject] forKey: @"subject"];
        [result setValue: [fromHeader realnameFromEMailStringWithFallback] forKey: @"author"];
        
        // sanity check for date header field:
        NSCalendarDate* messageDate = [im date];
        if ([(NSDate*)[NSDate dateWithTimeIntervalSinceNow: 15*60.0] compare: messageDate] != NSOrderedDescending) // if message's date is a future date
        {
        // broken message, set current date:
            messageDate = [NSCalendarDate date];
            if (NSDebugEnabled) NSLog(@"Found message with future date. Fixing broken date with 'now'.");
        }
        [result setValue:messageDate forKey: @"date"];
        
        // Note that this method operates on the encoded header field. It's OK because email
        // addresses are 7bit only.
        if ([G3Profile isMyEmailAddress:fromHeader])
        {
            [result addFlags:OPIsFromMeStatus];
        }
    }
    [im release];
    return result;
}

- (id)initWithEntity:(NSEntityDescription*)entity insertIntoManagedObjectContext:(NSManagedObjectContext*)context
{
    flagsCache = -1;
    return [super initWithEntity:entity insertIntoManagedObjectContext:context];
}

- (NSData *)transferData
{
    return [self valueForKeyPath:@"messageData.transferData"];
}

- (void)setTransferData:(NSData *)newData
{
    NSManagedObjectContext *context = [self managedObjectContext];
    NSEntityDescription *entity = [[[[context persistentStoreCoordinator] managedObjectModel] entitiesByName] objectForKey:@"MessageData"];
    NSManagedObject* messageData = [[[NSManagedObject alloc] initWithEntity:entity insertIntoManagedObjectContext: context] autorelease];
    
    [messageData setValue: newData forKey: @"transferData"];
    [self setValue: messageData forKey: @"messageData"];
}

- (NSString*) messageId
{
    [self willAccessValueForKey: @"messageId"];
    id result = [self primitiveValueForKey: @"messageId"];
    [self didAccessValueForKey: @"messageId"];
    return result;
}

- (unsigned) flags
{
    @synchronized(self)
    {
        if (flagsCache < 0)
        {
            flagsCache = 0;
            
            if ([[self valueForKey:@"isInSendJob"] boolValue]) flagsCache |= OPInSendJobStatus;
            if ([[self valueForKey:@"isQueued"] boolValue]) flagsCache |= OPQueuedStatus;
            if ([[self valueForKey:@"isInteresting"] boolValue]) flagsCache |= OPInterestingStatus;
            if ([[self valueForKey:@"isSeen"] boolValue]) flagsCache |= OPSeenStatus;
            if ([[self valueForKey:@"isJunk"] boolValue]) flagsCache |= OPJunkMailStatus;
            if ([[self valueForKey:@"isSendingBlocked"] boolValue]) flagsCache |= OPSendingBlockedStatus;
            if ([[self valueForKey:@"isFlagged"] boolValue]) flagsCache |= OPFlaggedStatus;
            if ([[self valueForKey:@"isFromMe"] boolValue]) flagsCache |= OPIsFromMeStatus;
            if ([[self valueForKey:@"isFulltextIndexed"] boolValue]) flagsCache |= OPFulltextIndexedStatus;
            if ([[self valueForKey:@"isAnswered"] boolValue]) flagsCache |= OPAnsweredStatus;
            if ([[self valueForKey:@"isDraft"] boolValue]) flagsCache |= OPDraftStatus;
        }
    }
    
    return flagsCache;
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

- (G3Message *)reference
{
    [self willAccessValueForKey:@"reference"];
    id reference = [self primitiveValueForKey:@"reference"];
    [self didAccessValueForKey:@"reference"];
    return reference;
}

- (G3Message *)referenceFind:(BOOL)find
{
    G3Message *result = [self reference];
    if (!result && find) 
    {
        NSEnumerator* e = [[[self internetMessage] references] reverseObjectEnumerator];
        NSString *refId;
        while (refId = [e nextObject]) 
        {
            result = [[self class] messageForMessageId:refId];
            
            if (result) 
            {
                [self setValue: result forKey: @"reference"];
                return result;
            }
        }
    }
    return nil;
}

- (G3Thread *)thread
{
    [self willAccessValueForKey:@"thread"];
    id thread = [self primitiveValueForKey:@"thread"];
    [self didAccessValueForKey:@"thread"];
    return thread;
}


- (G3Profile *)profile 
{
    id tmpObject;
    
    [self willAccessValueForKey:@"profile"];
    tmpObject = [self primitiveValueForKey:@"profile"];
    [self didAccessValueForKey:@"profile"];
    
    return tmpObject;
}

- (void)setProfile:(G3Profile *)value 
{
    [self willChangeValueForKey:@"profile"];
    [self setPrimitiveValue:value
                     forKey:@"profile"];
    [self didChangeValueForKey:@"profile"];
}

- (G3Thread *)threadCreate:(BOOL)doCreate
{
    G3Thread *thread = [self thread];
    
    if (doCreate && !thread) 
    {
        // do threading by reference
        thread = [[self referenceFind:YES] thread];
        
        if (!thread) 
        {
            thread = [G3Thread threadInManagedObjectContext:[self managedObjectContext]];
            [thread setValue:[self valueForKey:@"subject"] forKey:@"subject"];
        } 
        else 
        {
            // NSLog(@"Found Existing Thread with %d message(s). Updating it...", [thread messageCount]);
            // Set the thread's subject to be the first messages subject:
        }
        // We got one, so set it:
        [self setValue:thread forKey:@"thread"];
        [thread addMessage:self];
    }
    
    return thread;
}

/*
- (unsigned) numberOfReferences
{
    unsigned result = 0;
    G3Message* msg = self;
    while (msg = [msg reference]) result++;
    return result;
}
*/


- (NSAttributedString *)contentAsAttributedString
{
    return [[self internetMessage] bodyContent];
}

- (NSArray *)commentsInThread:(G3Thread *) thread
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


/*
- (NSData*) transferData
{	
	[self willAccessValueForKey: @"transferData"];
    NSData* transferData = [self primitiveValueForKey: @"transferData"];
    [self didAccessValueForKey: @"transferData"];
    
    return transferData;
}
*/

- (BOOL)isListMessage
/*" Returns YES, if Ginko thinks (from the message headers) that this message is from a mailing list (note, that a message can be both, a usenet article and an email). "*/
{
    OPInternetMessage *m = [self internetMessage];   
    
    // do more guesses here...
    return (([m bodyForHeaderField:@"List-Post"] != nil)
            || ([m bodyForHeaderField:@"List-Id"] != nil)
            || ([m bodyForHeaderField:@"X-List-Post"] != nil));
}

- (BOOL) isUsenetMessage
/*" Returns YES, if Ginko thinks (from the message headers) that this message is an Usenet News article (note, that a message can be both, a usenet article and an email), "*/
{
    return ([[self internetMessage] bodyForHeaderField:@"Newsgroups"] != nil);
}

- (BOOL) isEMailMessage
/*" Returns YES, if Ginko thinks (from the message headers) that this message is some kind of email (note, that a message can be both, a usenet article and an email). "*/
{
    return ([[self internetMessage] bodyForHeaderField:@"To"] != nil);
}

- (BOOL) isPublicMessage 
{
    return [self isListMessage] || [self isUsenetMessage];
}

- (BOOL)isDummy
{
    return [self transferData] == nil;
}

- (NSString*) senderName
/*" Returns the real name extracted from the 'From' header. "*/
{
    NSString* result = [self valueForKey: @"author"];
	/*
    if (!result) {
        NSString* name; 
        result = [self valueForKey: @"from"];
        if ([name = [result realnameFromEMailString] length]) {
            result = name;
        }
        [self setValue: result forKey: @"authorRealname"];
    }
	 */
    return result;
}


- (void) didTurnIntoFault
{
    NSLog(@"G3Message 0x%x turned into fault.", self);
    //[self setInternetMessage: nil];
}

- (void) didSave
{
    // Preserve memory by getting rid of the transient attribute:
    [self setPrimitiveValue: nil forKey: @"internetMessageCache"];
}

/*
- (void) dealloc
{
    [self setInternetMessage: nil];
    [super dealloc];
}
*/

- (void)putInSendJobStatus
{
    [self addFlags:OPInSendJobStatus];
}

- (void)removeInSendJobStatus
{
    [self removeFlags:OPInSendJobStatus];
}

@end
