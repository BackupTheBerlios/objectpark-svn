//
//  GIThread.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 02.08.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "GIThread.h"
#import <sqlite3.h>

@class G3Message;
@class G3MessageGroup;

@implementation GIThread

// CREATE TABLE ZTHREAD ( Z_ENT INTEGER, Z_PK INTEGER PRIMARY KEY, Z_OPT INTEGER, ZSIZE INTEGER, ZSTATS INTEGER, ZNUMBEROFMESSAGES INTEGER, ZSUBJECT VARCHAR, ZDATE TIMESTAMP );

+ (NSString*) databaseTableName
{
	return @"ZTHREAD";
}

+ (NSString*) prefetchedDatabaseColumns
/*" A comma-separated list of attributes to fetch. Those can be accessed in +newFromStatement at index two and up. "*/
{
	return @",ZDATE";
}

+ (NSString*) persistentAttributesPlist
{
	return 
	@"{"
	@"numberOfMessages = {ColumnName = ZNUMBEROFMESSAGES; AttributeClass = NSNumber;};"
	@"subject = {ColumnName = ZSUBJECT; AttributeClass = NSString;};"
	@"date = {ColumnName = ZDATE; AttributeClass = NSNumber;};"
	@"groups = {AttributeClass = GIMessageGroup; QueryString =\"select Z_4THREADS.Z_4GROUPS from Z_4THREADS where Z_4THREADS.Z_6THREADS=?\"; ContainerClass=NSMutableArray;};"
	@"messages = {AttributeClass = GIMessage; QueryString =\"select ZMESSAGE.ROWID from ZMESSAGE where ZTHREAD=?\"; ContainerClass=NSMutableArray;};"
	//@"groups = {AttributeClass = GIMessageGroup; JoinTableName = Z_4THREADS; SourceKeyColumnName = Z_6THREADS; TargetKeyColumnName = Z_4GROUPS; ContainerClass=NSArray;};"
	@"}";
}

- (void) addToGroups: (GIMessageGroup*) group
{
	//[self willChangeValueForKey: @"groups"];
	
	[self addValue: group forKey: @"groups"]; 
	
	//[self didChangeValueForKey: @"groups"];
}



- (void) removeFromGroups: (GIMessageGroup*) group
{
	[self removeValue: group forKey: @"groups"];
}


- (void) mergeMessagesFromThread: (GIThread*) otherThread
/*" Includes all messages from otherThread. otherThread is being deleted. "*/
{
    // put all messages from otherThread into self and remove otherThread
    G3Message *message;
    NSEnumerator *enumerator = [[otherThread messages] objectEnumerator];
    
    while (message = [enumerator nextObject]) {
        [self addMessage: message];
    }
    
    /*
	 // disconnecting another thread from all groups:
	 enumerator = [[otherThread valueForKey:@"groups"] objectEnumerator];
	 while (group = [enumerator nextObject])
	 {
		 [self removeGroup:group];
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
        [newThread addMessage:message];
    }
	
    // update numberOfMessages attribute:
    int newValue = [[self messages] count];
    [self setValue: [NSNumber numberWithInt:newValue] forKey: @"numberOfMessages"];
    
    if (newValue == 0) {
        // Disconnect self from all groups:
        NSEnumerator *enumerator = [[self valueForKey: @"groups"] objectEnumerator];
        GIMessageGroup *group;
        while (group = [enumerator nextObject]) {
            [self removeGroup: group];
        }
        
        [[self context] deleteObject: self];		
    }
    return newThread;
}


+ (id) newFromStatement: (sqlite3_stmt*) statement index: (int) index
/*" Overwritten from OPPersistentObject to support fetching the age attribute used for sorting together with the oid on fault creation time. This allows us to update e.g. the threadsByDate relation in GIMessageGroup without re-fetching all threads (which is slow). "*/
{
	GIThread* result = [super newFromStatement: statement index: index];
	if (index==1 && sqlite3_column_count(statement)>1) {
		result->age = sqlite3_column_int(statement, 2);
	}
	return result;
}


@end
