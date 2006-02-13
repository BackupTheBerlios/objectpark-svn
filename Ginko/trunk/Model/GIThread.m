//
//  GIThread.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 02.08.05.
//  Copyright 2005 Dirk Theisen. All rights reserved.
//

#import "GIThread.h"
#import "OPSQLiteConnection.h"
#import "OPPersistentObjectContext.h"
#import "NSArray+Extensions.h"
#import "GIMessage.h"
#import "OPInternetMessage.h"


#define THREADING   OPL_DOMAIN  @"Threading"
#define CREATION    OPL_ASPECT  0x01
#define REFERENCES  OPL_ASPECT  0x02
#define MERGING     OPL_ASPECT  0x04


@implementation GIThread

// CREATE TABLE ZTHREAD ( Z_ENT INTEGER, Z_PK INTEGER PRIMARY KEY, Z_OPT INTEGER, ZSIZE INTEGER, ZSTATS INTEGER, ZNUMBEROFMESSAGES INTEGER, ZSUBJECT VARCHAR, ZDATE TIMESTAMP );



+ (NSString*) databaseProperties
{
	return 
	@"{"
	@"  TableName = ZTHREAD;"
	@"  CreateStatements = (\""
	@"  CREATE TABLE ZTHREAD ( Z_ENT INTEGER, Z_PK INTEGER PRIMARY KEY, Z_OPT INTEGER, ZSIZE INTEGER, ZSTATS INTEGER, ZNUMBEROFMESSAGES INTEGER, ZSUBJECT VARCHAR, ZDATE TIMESTAMP);"
	@"  \");"
	@"}";
}


+ (NSString*) persistentAttributesPlist
{
	return 
	@"{"
	//@"numberOfMessages = {ColumnName = ZNUMBEROFMESSAGES; AttributeClass = NSNumber;};"
	@"subject = {ColumnName = ZSUBJECT; AttributeClass = NSString;};"
	@"date = {ColumnName = ZDATE; AttributeClass = NSCalendarDate;};"
	@"groups = {AttributeClass = GIMessageGroup; QueryString =\"select Z_4THREADS.Z_4GROUPS from Z_4THREADS where Z_4THREADS.Z_6THREADS=?\"; ContainerClass=NSMutableArray; JoinTableName=Z_4THREADS; InverseRelationshipKey=threadsByDate; SourceColumnName = Z_6THREADS; TargetColumnName = Z_4GROUPS; };"
	@"messages = {AttributeClass = GIMessage; QueryString =\"select ZMESSAGE.ROWID from ZMESSAGE where ZTHREAD=?\"; InverseRelationshipKey = thread;};"
	//@"groups = {AttributeClass = GIMessageGroup; JoinTableName = Z_4THREADS; SourceKeyColumnName = Z_6THREADS; TargetKeyColumnName = Z_4GROUPS; ContainerClass=NSArray; SortAttribute = age};"
	//@"groups = {AttributeClass = GIMessageGroup; SQL = \"select Z_4THREADS. from\"; ContainerClass=NSArray; SortAttribute = age};"
	@"}";
}

- (void) willDelete
{
	//NSLog(@"Will delete Thread!");
	//[[self valueForKey: @"messages"] makeObjectsPerformSelector: @selector(delete)];
	[super willDelete];
}

- (void) calculateDate
/*" Sets the date attribute according to that of the latest message in the receiver. This method fires all message faults - so be careful."*/
{
	NSDate* result = nil;
	NSEnumerator* oe = [[self valueForKey: @"messages"] objectEnumerator];
	GIMessage* message;
	while (message = [oe nextObject]) {
		NSDate* md = [message valueForKey: @"date"];
		if ([result compare: md]<=0) {
			result = md;
		}
	}
	[self setValue: result forKey: @"date"];
}

- (void) willSave
{
	[super willSave];
	
	if (![self valueForKey: @"date"]) [self calculateDate]; // fixing only for broken databases - can be removed later.
}

- (void)didChangeValueForKey:(NSString *)key 
{
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

- (void) addMessage:(GIMessage*)aMessage
{
    [aMessage setValue:self forKey:@"thread"];
}


- (void) addMessages:(NSArray*)someMessages
/*"Adds %someMessages to the receiver."*/
{
    NSEnumerator* messagesToAdd = [someMessages reverseObjectEnumerator];
    GIMessage* message;
    
    while (message = [messagesToAdd nextObject])
        [self addMessage:message];
}


- (void) mergeMessagesFromThread: (GIThread*) otherThread
/*" Moves all messages from otherThread into the receiver. otherThread is being deleted. "*/
{
    // Put all messages from otherThread into self and remove otherThread:
    GIMessage* message;
    NSArray* messages = [otherThread messages];
    
    OPDebugLog(THREADING, MERGING, @"Mergeing messages %@ into thread %@ with messages %@", messages, self, [self messages]);
    
    while (message = [messages lastObject]) {
		[message referenceFind: YES];
        [message setValue: self forKey: @"thread"]; // removes message from messages
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


- (NSArray*) messagesByTree
	/* Returns an array containing the result of a depth first search over all tree roots. */
{
    NSArray* allMessages = [self messages];
	NSMutableArray* result = [NSMutableArray arrayWithCapacity: [allMessages count]];

	[[self rootMessages] makeObjectsPerformSelector: @selector(addOrderedSubthreadToArray:) withObject: result];
	
	/*
    NSMutableArray* result = [NSMutableArray arrayWithCapacity: [allMessages count]];
    NSEnumerator* me = [allMessages objectEnumerator];
    GIMessage* message;
    while (message = [me nextObject]) {
		GIMessage* reference = [message reference];
        if (!reference || ![allMessages containsObject: reference]) {
            // Found a root message. Walk the tree and collect all nodes:
            [self treeWalkFrom: message addTo: result];
        }
    }

	if ([allMessages count]!=[result count]) {
		NSMutableArray* missing = [[allMessages mutableCopy] autorelease];
		[missing removeObjectsInArray: result];
		NSLog(@"Bug: messagesByTree doesn't work: only %u of %u total in %@ missing %@", [result count], [allMessages count], self, missing);
	}
	 	 */
    return result;
}

- (NSArray*) messages
{
    [self willAccessValueForKey: @"messages"];
    id messages = [self primitiveValueForKey: @"messages"];
    [self didAccessValueForKey: @"messages"];
    return messages;
}

- (void) addToGroups_Manually: (GIMessageGroup*) newGroup
/*" "*/
{
#warning OPPersistence: implement key-value-coding for relationships 
	// This may fire the groups relation:
	if (![[self valueForKey: @"groups"] containsObject: newGroup]) {
		// Add the thread to the group, if not already present:
		[self addValue: newGroup forKey: @"groups"];
	}
}


- (BOOL) hasUnreadMessages
/*" Returns YES, if any message contained is unread (OPSeenStatus). "*/
{    
	NSEnumerator* enumerator = [[self messages] objectEnumerator];
	GIMessage* message;
    while (message = [enumerator nextObject]) {
        if (![message hasFlags: OPSeenStatus]) {
            return YES;
        }
    }
    return NO;
}

- (NSArray*) rootMessages
/*" Returns all messages without reference in the receiver. "*/
{
    NSMutableArray* result = [NSMutableArray array];
	NSArray* messages = [self messages];
    NSEnumerator* me = [messages objectEnumerator];
    GIMessage *message;
    while (message = [me nextObject]) {
		GIMessage* reference = [message reference];
        if (!reference || ![messages containsObject: reference]) {
            [result addObject: message];
        }
    }
    return result;
}

- (void) setDate: (NSDate*) newDate
{
	NSDate* oldDate = [self valueForKey: @"date"];
	if (oldDate == nil || [oldDate compare: newDate]<0) {
		[self willChangeValueForKey: @"date"];	
		[self setPrimitiveValue: newDate forKey: @"date"];
		[self didChangeValueForKey: @"date"];	
		[[self valueForKey: @"groups"] makeObjectsPerformSelector: @selector(dateDidChangeOfThread:) 
													   withObject: self];
	}
}

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
+ (GIThread*) threadForMessage:(GIMessage*)aMessage
{
    GIThread* thread = [aMessage thread];
    
    if (thread)
        return thread;
        
    thread = [[[self alloc] init] autorelease];
    [thread insertIntoContext:[aMessage context]];
    [thread setValue:[aMessage valueForKey:@"subject"] forKey:@"subject"];
    [thread setValue:[aMessage valueForKey:@"date"] forKey:@"date"];
    
    [thread addMessage:aMessage];
    
    OPDebugLog(THREADING, CREATION, @"Created thread %@ for message %@ (%qu)", [aMessage messageId], [aMessage oid]);
    
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
+ (void) addMessageToAppropriateThread:(GIMessage*)message
{
    NSMutableArray* references = [NSMutableArray arrayWithArray:[[message internetMessage] references]];
    [references removeObject:[message messageId]];  // no self referencing allowed
    [references removeDuplicates];
    
    GIThread* thread = [self threadForMessage:message];
    
    NSEnumerator* enumerator = [references reverseObjectEnumerator];
    GIMessage* referencingMsg = message;
    GIMessage* referencedMsg;
    
    NSString* refId;
    while (refId = [enumerator nextObject]) {
        referencedMsg = [[message class] messageForMessageId:refId];
        
        if (referencedMsg) {
            OPDebugLog(THREADING, REFERENCES, @"%@ (%qu) -> %@ (%qu)", [referencingMsg messageId], [referencingMsg oid], [referencedMsg messageId], [referencedMsg oid]);
            [referencingMsg setValue:referencedMsg forKey: @"reference"];
            
            [[referencedMsg thread] mergeMessagesFromThread:thread];
            
            return;
        }
        
        // create dummy message
        referencedMsg = [GIMessage dummyMessageWithId:refId andDate:[message valueForKey:@"date"]];
        [thread addMessage:referencedMsg];
        
        OPDebugLog(THREADING, REFERENCES, @"%@ (%qu) -> %@ (%qu)", [referencingMsg messageId], [referencingMsg oid], [referencedMsg messageId], [referencedMsg oid]);
        [referencingMsg setValue:referencedMsg forKey: @"reference"];
        
        referencingMsg = referencedMsg;
    }
}





@end
