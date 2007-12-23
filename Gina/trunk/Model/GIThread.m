//
//  GIThread.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 02.08.05.
//  Copyright 2005 Dirk Theisen. All rights reserved.
//

#import "GIThread.h"
#import "OPPersistentObjectContext.h"
//#import "NSArray+Extensions.h"
#import "GIMessage.h"
//#import "OPInternetMessage.h"
#import "OPFaultingArray.h"
#import <Foundation/NSDebug.h>

#define THREADING   OPL_DOMAIN  @"Threading"
#define CREATION    OPL_ASPECT  0x01
#define REFERENCES  OPL_ASPECT  0x02
#define MERGING     OPL_ASPECT  0x04

NSString *GIThreadDidChangeNotification = @"GIThreadDidChangeNotification";

@implementation GIThread

- (id) init
{
	if (self = [super init]) {
		messages = [[OPFaultingArray alloc] init];
		messageGroups = [[OPFaultingArray alloc] init];
	}
	return self;
}

- (NSArray*) messageGroups
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
	if (! [date isEqual: newDate]) {
		[self willChangeValueForKey: @"date"];
		[date release];
		date = [newDate retain];
		[self didChangeValueForKey: @"date"];
	}
}

- (NSDate*) date
{
	return date;
}


- (void) dealloc
{
	[date release];
	[subject release];
	[messages release];
	[messagesByTree release];
	[super dealloc];	
}

- (id) initWithCoder: (NSCoder*) coder
{
	subject = [coder decodeObjectForKey: @"subject"];
	date = [coder decodeObjectForKey: @"date"];
	messages = [coder decodeObjectForKey: @"messages"];
	messageGroups = [coder decodeObjectForKey: @"messageGroups"];
	//[messages setParent: self];
	return self;
}

- (void) encodeWithCoder: (NSCoder*) coder
{
	[coder encodeObject: subject forKey: @"subject"];
	[coder encodeObject: date forKey: @"date"];
	[coder encodeObject: messages forKey: @"messages"];
	[coder encodeObject: messageGroups forKey: @"messageGroups"];
}





- (NSString*) description
{
	return [NSString stringWithFormat: @"%@ '%@' with %u messages", [super description], subject, [messages count]];
}

- (void) willDelete
{
	//NSLog(@"Will delete Thread!");
	[[self valueForKey: @"messages"] makeObjectsPerformSelector: @selector(delete)];
	[super willDelete];
}

- (void) calculateDate
/*" Sets the date attribute according to that of the latest message in the receiver. This method fires all message faults - so be careful."*/
{
	NSDate* result = nil;
	NSEnumerator* enumerator = [[self valueForKey: @"messages"] objectEnumerator];
	GIMessage *message;
	
	while (message = [enumerator nextObject]) 
	{
		NSDate *theDate = [message valueForKey: @"date"];
		if ([result compare:theDate] == NSOrderedDescending) 
		{
			result = theDate;
		}
	}
	
	[self setValue: result forKey: @"date"];
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

- (void)noteChange
{
	NSNotification *notification = [NSNotification notificationWithName:GIThreadDidChangeNotification object:self];
	[[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostASAP coalesceMask:NSNotificationCoalescingOnName | NSNotificationCoalescingOnSender forModes:nil];
}

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
    NSArray* otherMessages = [otherThread messages];
    
    if (NSDebugEnabled) NSLog(@"Merging messages %@ into thread %@ with messages %@", otherMessages, self, [self messages]);
    
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

- (unsigned) messageCount
{
    return (unsigned)[[self valueForKey: @"messages"] count]; 
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


- (OPFaultingArray*) messagesByTree
	/* Returns an array containing the result of a depth first search over all tree roots. */
{
	if (!messagesByTree) {
		NSArray* allMessages = [self messages];
		messagesByTree = [[OPFaultingArray alloc] initWithCapacity: [allMessages count]];
		[messagesByTree setParent: self];
		[[self rootMessages] makeObjectsPerformSelector: @selector(addOrderedSubthreadToArray:) withObject: messagesByTree];
	}	
    return messagesByTree;
}

- (BOOL) isLeaf
{
	return NO;
}


- (NSArray*) messages
{
    //[self willAccessValueForKey: @"messages"];
    //[self didAccessValueForKey: @"messages"];
    return messages;
}

//- (void) addToMessages: (GIMessage*) aMessage 
//{
//	[self willChangeValueForKey];
//
//
//}


- (BOOL)hasUnreadMessages
/*" Returns YES, if any message contained is unread (OPSeenStatus). "*/
{    
	NSEnumerator *enumerator = [[self messages] objectEnumerator];
	GIMessage *message;
    while (message = [enumerator nextObject]) 
	{
        if (![message hasFlags:OPSeenStatus]) 
		{
            return YES;
        }
    }
    return NO;
}

- (NSArray*) rootMessages
/*" Returns all messages without reference in the receiver. "*/
{
    NSMutableArray* result = [NSMutableArray array];
    NSEnumerator* me = [messages objectEnumerator];
    GIMessage *message;
    while (message = [me nextObject]) {
		GIMessage* reference = [message reference];
        if (!reference || NSNotFound == [messages indexOfObjectIdenticalTo: reference]) {
            [result addObject: message];
        }
    }
    return result;
}

//- (void) setDate: (NSDate*) newDate
//{
//	NSDate* oldDate = [self valueForKey: @"date"];
////	if (oldDate == nil || [oldDate compare: newDate]<0) {
//		[self willChangeValueForKey: @"date"];	
//		[self setPrimitiveValue: newDate forKey: @"date"];
//		[self didChangeValueForKey: @"date"];	
////		[[self valueForKey: @"groups"] makeObjectsPerformSelector: @selector(dateDidChangeOfThread:) 
////													   withObject: self];
////	}
//}

- (unsigned) commentDepth
	/*" Returns the the length of the longest comment chain in this thread. "*/
{
    NSEnumerator *re = [[self messages] objectEnumerator];
    GIMessage *msg;
    unsigned result = 0;
    while (msg = [re nextObject]) {
        result = MAX(result, [msg numberOfReferences]);
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
    
	if (NSDebugEnabled) NSLog(@"Created thread %@ for message %@ (%qu)", [aMessage messageId], [aMessage oid]);
    
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
    [references removeObject:[message messageId]];  // no self referencing allowed
    //[references removeDuplicates];
    
    GIThread *thread = [self threadForMessage:message];
    
    NSEnumerator *enumerator = [references reverseObjectEnumerator];
    GIMessage *referencingMsg = message;
    GIMessage *referencedMsg;
    
    NSString *refId;
    while (refId = [enumerator nextObject]) 
	{
        referencedMsg = [[message class] messageForMessageId:refId];
        
        if (referencedMsg) 
		{
			if (NSDebugEnabled) NSLog(@"%@ (%qu) -> %@ (%qu)", [referencingMsg messageId], [referencingMsg oid], [referencedMsg messageId], [referencedMsg oid]);
            [referencingMsg setValue:referencedMsg forKey:@"reference"];
            
            [[referencedMsg thread] mergeMessagesFromThread:thread];
            
            return;
        }
        
        // create dummy message
        referencedMsg = [GIMessage dummyMessageWithId:refId andDate:[message valueForKey:@"date"]];
        [referencedMsg setThread: thread];
		
		
		if (NSDebugEnabled) NSLog(@"%@ (%qu) -> %@ (%qu)", [referencingMsg messageId], [referencingMsg oid], [referencedMsg messageId], [referencedMsg oid]);
        [referencingMsg setValue:referencedMsg forKey:@"reference"];
        
        referencingMsg = referencedMsg;
    }
}

@end
