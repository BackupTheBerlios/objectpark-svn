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
	if (self = [super init]) {
		messages = [[OPFaultingArray alloc] init];
		messageGroups = [[OPPersistentSet alloc] init];
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
	[messagesByTree release]; messagesByTree = nil;
	[messages insertObject: message atIndex: index];
	// Warning: No inverse relationship handling here - use only setThread in GIMessage.
	if (! message.isSeen) {
		[self adjustUnreadMessageCountBy: 1];
	}
	if (message.date.timeIntervalSince1970 > self.date.timeIntervalSince1970) {
		self.date = message.date;
	}
}


- (void) removeObjectFromMessagesAtIndex: (NSUInteger) index
/*" Sent by the mutableArray proxy. Use setThread: in GIMessage in high-level code. "*/
{
	[messagesByTree release]; messagesByTree = nil;
	GIMessage* message = [messages objectAtIndex: index];
	[messages removeObjectAtIndex: index];
	// Warning: No inverse relationship handling here - use only setThread in GIMessage.

	if (! message.isSeen) {
		[self adjustUnreadMessageCountBy: -1];
	}
}

- (void) addPrimitiveMessageGroupsObject: (GIMessageGroup*) group
{
	[messageGroups addObject: group];
}

- (void) addMessageGroupsObject: (GIMessageGroup*) group
/*" Sent by the mutableArray proxy. "*/
{	
	[self addPrimitiveMessageGroupsObject: group];
	NSSet* selfSet = [NSSet setWithObject: self];
	[group willChangeValueForKey: @"threads" withSetMutation: NSKeyValueUnionSetMutation usingObjects: selfSet];
	[group addPrimitiveThreadsObject: self];
	[group didChangeValueForKey: @"threads" withSetMutation: NSKeyValueUnionSetMutation usingObjects: selfSet];	
}

- (void) removePrimitiveMessageGroupsObject: (GIMessageGroup*) group
{
	[messageGroups removeObject: group];
}

- (void) removeMessageGroupsObject:  (GIMessageGroup*) group
/*" Sent by the mutableArray proxy. "*/
{
	[self removePrimitiveMessageGroupsObject: group];
	NSSet* selfSet = [NSSet setWithObject: self];
	[group willChangeValueForKey: @"threads" withSetMutation: NSKeyValueMinusSetMutation usingObjects: selfSet];
	[(OPPersistentSet*) group.threads removeObject: self];
	[group removePrimitiveThreadsObject: self];
	[group didChangeValueForKey: @"threads" withSetMutation: NSKeyValueMinusSetMutation usingObjects: selfSet];
}

- (NSSet*) messageGroups
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

- (void) setDate: (NSDate*) newDate
{
	if (! [date isEqualToDate: newDate]) {
		
		// The group's thread relation (the set array) is sorted by date. Update it:
		for (GIMessageGroup* group in self.messageGroups) {
			NSMutableSet* threadIndex = [group mutableSetValueForKey: @"threads"];
			[threadIndex removeObject: self];
			[self willChangeValueForKey: @"date"];
		}
		
		[date release];
		date = [newDate retain];
		
		for (GIMessageGroup* group in self.messageGroups) {
			NSMutableSet* threadIndex = [group mutableSetValueForKey: @"threads"];
			[self didChangeValueForKey: @"date"];
			[threadIndex addObject: self];
		}
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
	subject = [[coder decodeObjectForKey: @"subject"] retain];
	date = [[coder decodeObjectForKey: @"date"] retain];
	messages = [[coder decodeObjectForKey: @"messages"] retain];
	messageGroups = [[coder decodeObjectForKey: @"messageGroups"] retain];
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

+ (void) context: (OPPersistentObjectContext*) context willDeleteInstanceWithOID: (OID) oid
{
	[[context objectForOID: oid] willDelete]; // loads instance (slow)
}

- (void) willDelete
{
	NSLog(@"Will delete Thread %@ from %@", self, self.messageGroups);
	
	NSMutableSet* ggroups = [self mutableSetValueForKey: @"messageGroups"];
//	while (ggroups.count) {
//		[ggroups removeLastObject];
//	}
	[ggroups removeAllObjects]; // TODO: check, if this notifies
	
	[self.messages makeObjectsPerformSelector: @selector(delete)];
	
	[super willDelete];
}

- (GIMessage*) nextMessageForMessage: (GIMessage*) previousMessage
/*" Delivers the next message the user might want to see. Pass nil for the first unread message. If there is no unread message in the receiver, the next message (byTree) will be returned. Pass in a previous messsage to start search there. "*/
{
	NSArray* sortedMessages = self.messagesByTree;
	if (sortedMessages.count) {
		unsigned index = 0; // index of the previous message
		if (previousMessage) {
			unsigned found = [sortedMessages indexOfObjectIdenticalTo: previousMessage];
			if (found != NSNotFound) index = (found+1) % sortedMessages.count;
		}
		unsigned startIndex = index;
		BOOL hasUnread = self.unreadMessageCount > 0;
		// Start searching at index and find an unread message:
		do {
			GIMessage* nextMessage = [sortedMessages objectAtIndex: index];
			if ((! hasUnread) || ! [nextMessage hasFlags: OPSeenStatus]) {
				return nextMessage;
			}
			index = (index+1) % sortedMessages.count;
		} while (index != startIndex);
	}
	return nil;
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
	time = NSSwapHostIntToBig(time);
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
	[super didChangeValueForKey:key];
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
- (NSArray*) messagesByTree
{
	//NSArray* previousMessagesByTree = messagesByTree;
	NSArray* allMessages = [self messages];
	if (!messagesByTree) {
		messagesByTree = [[OPFaultingArray alloc] initWithCapacity: allMessages.count];
		[[self rootMessages] makeObjectsPerformSelector: @selector(addOrderedSubthreadToArray:) withObject: messagesByTree];
	}	
	if (messagesByTree.count != allMessages.count) {
		messagesByTree = [[OPFaultingArray alloc] initWithCapacity: allMessages.count];
		[[self rootMessages] makeObjectsPerformSelector: @selector(addOrderedSubthreadToArray:) withObject: messagesByTree];
		NSAssert2(messagesByTree.count == allMessages.count, @"MessagesByTree does not deliver same number of messages (%u) as allMessages (%u)", 
			  messagesByTree.count, allMessages.count);
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
		BOOL nowSeen = [message hasFlags:OPSeenStatus];
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
	[[aMessage context] insertObject:thread];
	
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
	OPPersistentObjectContext* context = [OPPersistentObjectContext defaultContext];
	
    while (refId = [references lastObject]) {
        referencedMsg = [context messageForMessageId: refId];
        
        if (referencedMsg) 
		{
			if (NSDebugEnabled) NSLog(@"%@ (%qu) -> %@ (%qu)", referencingMsg.messageId, referencingMsg.oid, referencedMsg.messageId, referencedMsg.oid);
            referencingMsg.reference = referencedMsg;
            
            [referencedMsg.thread mergeMessagesFromThread:thread];
            
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
