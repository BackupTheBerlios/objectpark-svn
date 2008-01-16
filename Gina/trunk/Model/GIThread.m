//
//  GIThread.m
//  Gina
//
//  Created by Dirk Theisen on 02.08.05.
//  Copyright 2005 Dirk Theisen. All rights reserved.
//

#import "GIThread.h"
#import "OPPersistentObjectContext.h"
#import "NSArray+Extensions.h"
#import "GIMessageBase.h"
#import "GIMessage.h"
#import "GIMessageGroup.h"
#import "OPInternetMessage.h"
#import "GIMessageBase.h"
#import "OPFaultingArray.h"
#import <Foundation/NSDebug.h>

#define THREADING   OPL_DOMAIN  @"Threading"
#define CREATION    OPL_ASPECT  0x01
#define REFERENCES  OPL_ASPECT  0x02
#define MERGING     OPL_ASPECT  0x04

NSString *GIThreadDidChangeNotification = @"GIThreadDidChangeNotification";

@implementation GIThread

+ (NSSet*) keyPathsForValuesAffectingIsSeen
{
	return [NSSet setWithObject: @"unreadMessageCount"];
}

- (id) init
{
	if (self = [super init]) 
	{
		messages = [[OPFaultingArray alloc] init];
		messageGroups = [[OPFaultingArray alloc] init];
	}
	return self;
}

- (BOOL) isSeen
/*" Returns YES, if any message contained is unread (OPSeenStatus). "*/
{    
	return unreadMessageCount == 0;
}

- (int) unreadMessageCount
{
	return unreadMessageCount;
}

- (void) adjustUnreadMessageCountBy: (int) change
{
	if (change) {
		[self willChangeValueForKey: @"unreadMessageCount"];
		unreadMessageCount += change;
		[self didChangeValueForKey: @"unreadMessageCount"];
		NSParameterAssert(change<=1 && change >=-1);
		[messageGroups makeObjectsPerformSelector: change == -1 ? @selector(decreaseUnreadMessageCount) : @selector(increaseUnreadMessageCount)];
	}
}

- (void) insertObject: (GIMessage*) message inMessagesAtIndex: (NSUInteger) index
/*" Sent by the mutableArray proxy. Use setThread: in GIMessage in high-level code. "*/
{
	[messages insertObject: message atIndex: index];
	// No inverse relationship handling here - use only setThread in GIMessage.
	if (! message.isSeen) {
		[self adjustUnreadMessageCountBy: 1];
	}
}


- (void) removeObjectFromMessagesAtIndex: (NSUInteger) index
/*" Sent by the mutableArray proxy. Use setThread: in GIMessage in high-level code. "*/
{
	GIMessage* message = [messages objectAtIndex: index];
	[messages removeObjectAtIndex: index];
	// No inverse relationship handling here - use only setThread in GIMessage.

	if (! message.isSeen) {
		[self adjustUnreadMessageCountBy: -1];
	}
}

- (void) insertPrimitiveObject: (GIMessageGroup*) group inMessageGroupsAtIndex: (NSUInteger) index
{
	[messageGroups insertObject: group atIndex: index];
}

- (void) insertObject: (GIMessageGroup*) group inMessageGroupsAtIndex: (NSUInteger) index
/*" Sent by the mutableArray proxy. "*/
{
	[self insertPrimitiveObject: group inMessageGroupsAtIndex: index];
	NSSet* selfSet = [NSSet setWithObject: self];
	[group willChangeValueForKey: @"threads" withSetMutation: NSKeyValueUnionSetMutation usingObjects: selfSet];
	[group addPrimitiveThreadsObject: self];
	[group didChangeValueForKey: @"threads" withSetMutation: NSKeyValueUnionSetMutation usingObjects: selfSet];
}

- (void) removePrimitiveObjectFromMessageGroupsAtIndex: (NSUInteger) index
{
	[messageGroups removeObjectAtIndex: index];
}

- (void) removeObjectFromMessageGroupsAtIndex: (NSUInteger) index
/*" Sent by the mutableArray proxy. "*/
{
	GIMessageGroup* group = [messageGroups objectAtIndex: index];
	[self removePrimitiveObjectFromMessageGroupsAtIndex: index];
	NSSet* selfSet = [NSSet setWithObject: self];
	[group willChangeValueForKey: @"threads" withSetMutation: NSKeyValueMinusSetMutation usingObjects: selfSet];
//	[(OPPersistentSet*) group.threads removeObject: self]; 
	[group removePrimitiveThreadsObject: self];
	[group didChangeValueForKey: @"threads" withSetMutation: NSKeyValueMinusSetMutation usingObjects: selfSet];
}

- (NSArray *)messageGroups
{
	return messageGroups;
}

- (void) willRevert
{
	[date release]; date = nil;
	[subject release]; subject = nil;
	[messages release]; messages = nil;
	[messagesByTree release]; messagesByTree = nil;
	[messageGroups release]; messageGroups = nil;
}

- (void) setSubject: (NSString*) newSubject
{
	if (! [subject isEqualToString: newSubject]) {
		[self willChangeValueForKey: @"subject"];
		[subject release];
		subject = [newSubject copy];
		[self didChangeValueForKey: @"subject"];
	}
}

- (NSString*) subject
{
	return subject;
}

- (void)setDate:(NSDate *)newDate
{
	if (! [date isEqual:newDate]) 
	{
		[self willChangeValueForKey:@"date"];
		[date release];
		date = [newDate retain];
		[self didChangeValueForKey:@"date"];
	}
}

- (NSDate *)date
{
	return date;
}

- (void)dealloc
{
	[date release];
	[subject release];
	[messages release];
	[messagesByTree release];
	[messageGroups release];
	[super dealloc];	
}

- (id) initWithCoder: (NSCoder*) coder
{
	subject = [coder decodeObjectForKey: @"subject"];
	date = [coder decodeObjectForKey: @"date"];
	messages = [coder decodeObjectForKey: @"messages"];
	messageGroups = [coder decodeObjectForKey: @"messageGroups"];
	unreadMessageCount = [coder decodeIntForKey: @"unreadMessageCount"];
	//[messages setParent: self];
	return self;
}

- (void) encodeWithCoder: (NSCoder*) coder
{
	[coder encodeObject: subject forKey: @"subject"];
	[coder encodeObject: date forKey: @"date"];
	[coder encodeObject: messages forKey: @"messages"];
	[coder encodeObject: messageGroups forKey: @"messageGroups"];
	[coder encodeInt: unreadMessageCount forKey: @"unreadMessageCount"];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ '%@' with %u messages", [super description], subject, [messages count]];
}

- (void) willDelete
{
	//NSLog(@"Will delete Thread %@.", self);
	[[self valueForKey: @"messages"] makeObjectsPerformSelector: @selector(delete)];
	[[self mutableArrayValueForKey: @"messageGroups"] removeAllObjects];
	[super willDelete];
}

/*" Sets the date attribute according to that of the latest message in the receiver. This method fires all message faults - so be careful."*/
- (void)calculateDate
{
	NSDate *result = nil;
	
	for (GIMessage *message in [self messages])
	{
		NSDate *theDate = message.date;
		if ([result compare:theDate] == NSOrderedDescending) 
		{
			result = theDate;
		}
	}
	
	self.date = result;
}

- (void) appendBTreeBytesForKey: (NSString*) key to: (NSMutableData*) data
{
	// The sortKeyPath should be "date":
	NSInteger time = (NSInteger)[[self valueForKey: @"date"] timeIntervalSince1970];
	time = NSSwapHostIntToLittle(time);
	[data appendBytes: &time length: 4];
}

/*
- (void) willSave
{
	[super willSave];
	
	//if (![self valueForKey: @"date"]) [self calculateDate]; // fixing only for broken databases - can be removed later.
}
*/

//- (void)didChange:(NSKeyValueChange)change valuesAtIndexes:(NSIndexSet *)indexes forKey:(NSString *)key
//{
//	while (YES) {};
//}


//- (void)noteChange
//{
//	NSNotification *notification = [NSNotification notificationWithName:GIThreadDidChangeNotification object:self];
//	[[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostASAP coalesceMask:NSNotificationCoalescingOnName | NSNotificationCoalescingOnSender forModes:nil];
//}

- (void)didChangeValueForKey:(NSString *)key 
{
	// invalidating cache:
	[messagesByTree release]; messagesByTree = nil;

	// notifying main thread about message relation changes:
//	if ([key isEqualToString:@"messages"])
//	{
//		[self performSelectorOnMainThread:@selector(noteChange) withObject:nil waitUntilDone:NO];
//	}
//	
	[super didChangeValueForKey:key];
	
	/*
	if ([key isEqualToString: @"messages"]) {
		OPFaultingArray* messages = [self valueForKey: @"messages"]; //inefficient!! //[attributes objectForKey: @"messages"];
		if (messages) {
			int messageCount = [messages count];
			[self setValue: [NSNumber numberWithUnsignedInt: messageCount] forKey: @"numberOfMessages"];
		}
		[messages makeObjectsPerformSelector: @selector(flushNumberOfReferencesCache)];
	}
	 */
}

/*
- (void) addToGroups: (GIMessageGroup*) group
{
	[self willChangeValueForKey: @"groups"];
	[self addValue: group forKey: @"groups"]; 
	[self didChangeValueForKey: @"groups"];
}

- (void) removeFromGroups: (GIMessageGroup*) group
{
	[self willChangeValueForKey: @"groups"];
	[self removeValue: group forKey: @"groups"];
	[self didChangeValueForKey: @"groups"];
}
*/

//- (void) addMessage: (GIMessage*) aMessage
//{
//    [aMessage setValue: self forKey: @"thread"];
////	if (! [[self valueForKey: @"subject"] length] && [[aMessage valueForKey: @"subject"] length]) {
////		// If the thread does not yet have a proper subject, take the one from the first message thast does.
////		[self setValue: [aMessage valueForKey: @"subject"] forKey: @"subject"];
////	}
//}

//- (void) addMessages: (NSArray*) someMessages
///*"Adds %someMessages to the receiver."*/
//{
//    NSEnumerator* messagesToAdd = [someMessages reverseObjectEnumerator];
//    GIMessage* message;
//    
//    while (message = [messagesToAdd nextObject]) {
//        [self addMessage: message];
//	}
//}

- (void) mergeMessagesFromThread: (GIThread*) otherThread
/*" Moves all messages from otherThread into the receiver. otherThread is being deleted. "*/
{
	if (otherThread == self) return;
	
    // Put all messages from otherThread into self and remove otherThread:
    GIMessage* message;
    
    if (NSDebugEnabled) NSLog(@"Merging messages %@ into thread %@ with messages %@", [otherThread messages], self, [self messages]);
    
    while (message = [[otherThread messages] lastObject]) {
		[message referenceFind: YES];
        message.thread = self; // removes message from messages
    }
	NSAssert1([otherThread messageCount] ==  0, @"Thread not empty: %@ - loosing message.", otherThread);
	
    [otherThread delete];	
}




//+ (id) newFromStatement: (sqlite3_stmt*) statement index: (int) index
////" Overwritten from OPPersistentObject to support fetching the age attribute used for sorting together with the oid on fault creation time. This allows us to update e.g. the threadsByDate relation in GIMessageGroup without re-fetching all threads (which is slow). "/
//{
//	GIThread* result = [super newFromStatement: statement index: index];
//	
//	if (result) {
//		int columnCount = sqlite3_column_count(statement);
//		index++; // forward to next column, i.e. the date
//		if (columnCount>index) {
//			result->age = sqlite3_column_int(statement, index);
//		}
//	}
//	return result;
//}

- (NSUInteger) messageCount
{
    return [[self messages] count]; 
}

- (BOOL) containsSingleMessage
{
	return [self messageCount] <= 1;
}

/*
- (void) treeWalkFrom: (GIMessage*) localRoot addTo: (NSMutableArray*) result
{
    [result addObject: localRoot];
    NSArray* comments = [localRoot commentsInThread: self];
    int i;
    int commentCount = [comments count];
    for (i=0; i<commentCount; i++) {
        [self treeWalkFrom: [comments objectAtIndex: i] addTo: result];
    }
}


- (NSArray*) subthreadWithMessage: (GIMessage*) aMessage

{
    NSMutableArray* result = [NSMutableArray array];
	[self treeWalkFrom: aMessage addTo: result];
    return result;
}
*/

/*" Returns an array containing the result of a depth first search over all tree roots. "*/
- (NSArray *)messagesByTree
{
	if (!messagesByTree) 
	{
		NSArray* allMessages = [self messages];
		messagesByTree = [[OPFaultingArray alloc] initWithCapacity: [allMessages count]];
		//[messagesByTree setParent: self];
		[[self rootMessages] makeObjectsPerformSelector: @selector(addOrderedSubthreadToArray:) withObject: messagesByTree];
	}	
    return messagesByTree;
}

- (BOOL)isLeaf
{
	return NO;
}

- (NSArray *)messages
{
    return messages;
}

//- (void) addToMessages: (GIMessage*) aMessage 
//{
//	[self willChangeValueForKey];
//
//
//}



- (NSArray *)rootMessages
/*" Returns all messages without reference in the receiver. "*/
{
    NSMutableArray* result = [NSMutableArray array];
	
	for (GIMessage *message in [self messages])
	{
		GIMessage *reference = message.reference;
        if (!reference || NSNotFound == [messages indexOfObjectIdenticalTo:reference]) 
		{
            [result addObject:message];
        }
    }
    return result;
}


- (void) didToggleFlags: (unsigned) flags ofContainedMessage: (GIMessage*) message
{
	if (flags & OPSeenStatus) {
		BOOL nowSeen = [message hasFlags: OPSeenStatus];
		[self adjustUnreadMessageCountBy: nowSeen ? -1 : 1]; 
	}
}

/*" Returns the the length of the longest comment chain in this thread. "*/
- (NSUInteger)commentDepth
{
    NSUInteger result = 0;
	
	for (GIMessage *message in [self messages])
	{
        result = MAX(result, [message numberOfReferences]);
    }
    return result + 1;
}

/*"Returns the thread a message is in.
   If the message is not yet in a thread it creates a new one and inserts the
   message into it."*/
+ (GIThread *)threadForMessage:(GIMessage *)aMessage
{
    GIThread *thread = aMessage.thread;
    
    if (thread) return thread;
        
    thread = [[[self alloc] init] autorelease];
	[[aMessage context] insertObject: thread];
	
	thread.subject = aMessage.subject;
	thread.date = aMessage.date;
	aMessage.thread = thread;    
    
	if (NSDebugEnabled) NSLog(@"Created thread %@ for message %@ (%llx)", self, [aMessage messageId], [aMessage oid]);
    
    return thread;
}

/*"Adds aMessage to the thread it belongs to.
   I.e. a chain of messages is created from the references that starts with the
   nearest non existing ancestor of aMessage and ends with aMessage.
   So all of the messages in the chain with the exception of the last one (which
   is aMessage) are dummy messages.
   If the direct ancestor of aMessage does exist (i.e. is a non dummy message)
   the chain will consist of only a single message: aMessage.
   If the direct ancestor of the first message in the chain exists the chain is
   connected to that message and the chain is added to its thread.
   If it does not exist that chain is added to a newly created thread."*/
+ (void)addMessageToAppropriateThread:(GIMessage *)message
{
    NSMutableArray *references = [NSMutableArray arrayWithArray:[[message internetMessage] references]];
    [references removeObject:message.messageId];  // no self referencing allowed
    //[references removeDuplicates];
    
    GIThread *thread = [self threadForMessage:message];
    
    //NSEnumerator *enumerator = [references reverseObjectEnumerator];
    GIMessage *referencingMsg = message;
    GIMessage *referencedMsg;
    
    NSString *refId;
    while (refId = [references lastObject]) 
	{
        referencedMsg = [[OPPersistentObjectContext defaultContext] messageForMessageId:refId];
        
        if (referencedMsg) 
		{
			if (NSDebugEnabled) NSLog(@"%@ (%qu) -> %@ (%qu)", referencingMsg.messageId, referencingMsg.oid, referencedMsg.messageId, referencedMsg.oid);
            referencingMsg.reference = referencedMsg;
            
            [[referencedMsg thread] mergeMessagesFromThread:thread];
            
            return;
        }
        
        // create dummy message
        referencedMsg = [GIMessage dummyMessageWithId:refId andDate:message.date];
        referencedMsg.thread = thread;
		
		if (NSDebugEnabled) NSLog(@"%@ (%qu) -> %@ (%qu)", referencingMsg.messageId, referencingMsg.oid, referencedMsg.messageId, referencedMsg.oid);
        referencingMsg.reference = referencedMsg;
        
        referencingMsg = referencedMsg;
		[references removeLastObject];
    }
	
}

@end
