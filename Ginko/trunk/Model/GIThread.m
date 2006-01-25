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
#import "GIMessage.h"

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
	[super willDelete];
}

- (void) willSave
{
	[super willSave];
}

- (void) didChangeValueForKey: (NSString*) key 
{
	[super didChangeValueForKey: key];
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


- (void) mergeMessagesFromThread: (GIThread*) otherThread
/*" Moves all messages from otherThread into the receiver. otherThread is being deleted. "*/
{
    // Put all messages from otherThread into self and remove otherThread:
    GIMessage* message;
    NSArray* messages = [otherThread messages];
    
    while (message = [messages lastObject]) {
		[message referenceFind: YES];
        [message setValue: self forKey: @"thread"]; // removes message from messages
    }
	NSAssert1([otherThread messageCount] ==  0, @"Thread not empty: %@ - loosing message.", otherThread);
	
    [otherThread delete];		
}


- (GIThread*) splitWithMessage: (GIMessage*) aMessage
	/*" Splits the receiver into two threads. Returns a thread containing aMessage and comments and removes these messages from the receiver. "*/
{
    GIThread* newThread = [[[[self class] alloc] init] autorelease];
    NSEnumerator* enumerator;
    GIMessage* message;
    
    enumerator = [[self subthreadWithMessage: aMessage] objectEnumerator];
    while (message = [enumerator nextObject]) {
        [newThread addValue: message forKey: @"messages"];
    }
    return newThread;
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
/*" Returns all messages of this thread directly or indirectly referencing aMessage, sorted by tree walk. Does it include aMessage? "*/
{
    NSMutableArray* result = [NSMutableArray array];
	[self treeWalkFrom: aMessage addTo: result];
    return result;
}


- (NSArray*) messagesByTree
	/* Returns an array containing the result of a depth first search over all tree roots. */
{
    NSArray* allMessages = [self messages];
    NSMutableArray* result = [NSMutableArray arrayWithCapacity: [allMessages count]];
    NSEnumerator* me = [allMessages objectEnumerator];
    GIMessage* message;
    while (message = [me nextObject]) {
        if (![message reference]) {
            // Found a root message. Walk the tree and collect all nodes:
            [self treeWalkFrom: message addTo: result];
        }
    }
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
        if (!reference || ![messages containsObject: [message reference]]) {
            [result addObject: message];
        }
    }
    return result;
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

@end
