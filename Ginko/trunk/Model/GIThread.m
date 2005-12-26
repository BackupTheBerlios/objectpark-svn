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
	@"numberOfMessages = {ColumnName = ZNUMBEROFMESSAGES; AttributeClass = NSNumber;};"
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
	NSLog(@"Will delete Thread!");
	[super willDelete];
}


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


- (void) mergeMessagesFromThread: (GIThread*) otherThread
/*" Includes all messages from otherThread. otherThread is being deleted. "*/
{
    // put all messages from otherThread into self and remove otherThread
    GIMessage *message;
    NSEnumerator *enumerator = [[otherThread messages] objectEnumerator];
    
    while (message = [enumerator nextObject]) {
        [self addToMessages: message];
    }
    
    /*
	 // disconnecting another thread from all groups:
	 enumerator = [[otherThread valueForKey: @"groups"] objectEnumerator];
	 while (group = [enumerator nextObject])
	 {
		 [self removeFromGroups: group];
	 }
     */
	
    [[self context] deleteObject: otherThread];		
}

- (GIThread*) splitWithMessage: (GIMessage*) aMessage
	/*" Splits the receiver into two threads. Returns a thread containing aMessage and comments and removes these messages from the receiver. "*/
{
    GIThread *newThread = [[[[self class] alloc] init] autorelease];
    NSEnumerator *enumerator;
    GIMessage *message;
    
    enumerator = [[self subthreadWithMessage: aMessage] objectEnumerator];
    while (message = [enumerator nextObject]) {
        [newThread addToMessages: message];
    }
	
    // update numberOfMessages attribute:
    int newValue = [[self messages] count];
    [self setValue: [NSNumber numberWithInt:newValue] forKey: @"numberOfMessages"];
    
    if (newValue == 0) {
        // Disconnect self from all groups:
        NSEnumerator *enumerator = [[self valueForKey: @"groups"] objectEnumerator];
        GIMessageGroup *group;
        while (group = [enumerator nextObject]) {
            [self removeFromGroups: group];
        }
        
        [[self context] deleteObject: self];		
    }
    return newThread;
}


+ (id) newFromStatement: (sqlite3_stmt*) statement index: (int) index
//" Overwritten from OPPersistentObject to support fetching the age attribute used for sorting together with the oid on fault creation time. This allows us to update e.g. the threadsByDate relation in GIMessageGroup without re-fetching all threads (which is slow). "/
{
#warning Note, that we also want to set the age when the fault already existed (without age).

	GIThread* result = [super newFromStatement: statement index: index];
	
	if (result) {
		int columnCount = sqlite3_column_count(statement);
		index++; // forward to next column, i.e. the date
		if (columnCount>index) {
			result->age = sqlite3_column_int(statement, index);
		}
	}
	return result;
}

- (unsigned) messageCount
{
    return (unsigned)[[self valueForKey: @"numberOfMessages"] intValue]; 
}

- (BOOL) containsSingleMessage
{
	return [[self valueForKey: @"numberOfMessages"] intValue] == 1;
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
/*" Returns all messages of this thread directly or indirectly referencing aMessage, sorted by tree walk. "*/
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

- (BOOL) hasUnreadMessages
{    
	NSEnumerator *enumerator = [[self messages] objectEnumerator];
	GIMessage *message;
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
    NSMutableArray *result = [NSMutableArray array];
    NSEnumerator *me = [[self messages] objectEnumerator];
    GIMessage *message;
    while (message = [me nextObject]) {
        if (![message reference]) {
            [result addObject:message];
        }
    }
    return result;
}

- (void) addToMessages: (GIMessage*) message
{
	[self willAccessValueForKey: @"messages"];
	[self addValue: message forKey: @"messages"];
	[self didAccessValueForKey: @"messages"];
}

- (void) removeFromMessages: (GIMessage*) message
{
	[self willAccessValueForKey: @"messages"];
	[self removeValue: message forKey: @"messages"];
	[self didAccessValueForKey: @"messages"];
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
