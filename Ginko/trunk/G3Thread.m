//
//  G3Thread.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 02.12.04.
//  Copyright 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "G3Thread.h"
#import "G3Message.h"
#import "G3MessageGroup.h"
#import "NSManagedObjectContext+Extensions.h"
#import "NSArray+Extensions.h"

@implementation G3Thread

+ (NSString *)URIStringPrefix
{
    static NSString *prefix = nil;
    
    if (! prefix)
    {
        NSPersistentStoreCoordinator *sc = [[NSManagedObjectContext threadContext] persistentStoreCoordinator];
                
        prefix = [[NSString stringWithFormat:@"x-coredata://%@/Thread/p", [[sc metadataForPersistentStore:[[sc persistentStores] objectAtIndex:0]] objectForKey:NSStoreUUIDKey]] retain];
    }
    
    return prefix;
}

- (id) init
/*" Adds the reciever to the default managed object context. "*/
{
    return [self initWithManagedObjectContext:[NSManagedObjectContext threadContext]];
}

+ (G3Thread *)threadInManagedObjectContext:(NSManagedObjectContext *)aContext
/*" Creates a new persistent thread in the default managed object context. "*/
{	
    return [[[self alloc] initWithManagedObjectContext:aContext] autorelease];
}

- (unsigned)messageCount
{
    return (unsigned)[[self valueForKey:@"numberOfMessages"] intValue]; 
}

- (NSSet *)messages
{
    [self willAccessValueForKey: @"messages"];
    id messages = [self primitiveValueForKey: @"messages"];
    [self didAccessValueForKey: @"messages"];
    return messages;
}
/*
- (void) addMessage: (G3Message*) message
{
    [self addValue: message toRelationshipWithKey: @"messages"];
    // update numberOfMessages attribute:
    int newValue = [[self messages] count];
    [self setValue: [NSNumber numberWithInt: newValue] forKey: @"numberOfMessages"];
    
    // Set the thread's date to the date of the latest message:
    NSCalendarDate* threadDate = [self valueForKey: @"date"];
    NSCalendarDate* messageDate = [message valueForKey: @"date"];
    if ((!threadDate) || [messageDate compare: threadDate]==NSOrderedDescending) {
        [self setValue: messageDate forKey: @"date"];
    }
}
*/

- (void)addGroup:(G3MessageGroup *)value 
{    
    NSSet *changedObjects = [[NSSet alloc] initWithObjects:&value count:1];
    
    [self willChangeValueForKey:@"groups" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changedObjects];
    [[self primitiveValueForKey:@"groups"] addObject: value];
    [self didChangeValueForKey:@"groups" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changedObjects];
    
    [changedObjects release];
}

- (void)addGroups:(NSSet *)someGroups
{
    [self willChangeValueForKey:@"groups"
                withSetMutation:NSKeyValueUnionSetMutation
                   usingObjects:someGroups];
    [[self primitiveValueForKey:@"groups"] unionSet:someGroups];
    [self didChangeValueForKey:@"groups"
               withSetMutation:NSKeyValueUnionSetMutation
                  usingObjects:someGroups];
}

- (void)removeGroup:(G3MessageGroup *)value 
{
    NSSet *changedObjects = [[NSSet alloc] initWithObjects:&value count:1];
    
    [self willChangeValueForKey:@"groups" withSetMutation:NSKeyValueMinusSetMutation usingObjects:changedObjects];
    [[self primitiveValueForKey:@"groups"] removeObject:value];
    [self didChangeValueForKey:@"groups" withSetMutation:NSKeyValueMinusSetMutation usingObjects:changedObjects];
    
    [changedObjects release];
}

- (void) removeFromAllGroups
{
    [self setValue: [NSSet set] forKey: @"groups"];
}

- (void)addMessage:(G3Message *)aMessage
{
    NSSet *changedObjects = [[NSSet alloc] initWithObjects:&aMessage count:1];
    [self willChangeValueForKey:@"messages"
                withSetMutation:NSKeyValueUnionSetMutation
                   usingObjects:changedObjects];
    [[self primitiveValueForKey:@"messages"] addObject:aMessage];
    [self didChangeValueForKey:@"messages"
               withSetMutation:NSKeyValueUnionSetMutation
                  usingObjects:changedObjects];
    [changedObjects release];

    // update numberOfMessages attribute:
    int newValue = [[self messages] count];
    [self setValue: [NSNumber numberWithInt: newValue] forKey: @"numberOfMessages"];
    
    // Set the thread's date to the date of the latest message:
    NSCalendarDate* threadDate = [self valueForKey: @"date"];
    NSCalendarDate* messageDate = [aMessage valueForKey: @"date"];
    if ((!threadDate) || [messageDate compare: threadDate]==NSOrderedDescending) {
        [self setValue: messageDate forKey: @"date"];
    }
}

- (void) removeMessage: (G3Message*) aMessage
{
    NSSet *changedObjects = [[NSSet alloc] initWithObjects:&aMessage count:1];
    [self willChangeValueForKey:@"messages"
                withSetMutation:NSKeyValueMinusSetMutation
                   usingObjects:changedObjects];
    [[self primitiveValueForKey:@"messages"] removeObject:aMessage];
    [self didChangeValueForKey:@"messages"
               withSetMutation:NSKeyValueMinusSetMutation
                  usingObjects:changedObjects];
    [changedObjects release];

    // update numberOfMessages attribute:
    int newValue = [[self messages] count];
    [self setValue: [NSNumber numberWithInt: newValue] forKey:@"numberOfMessages"];    

    if (newValue == 0) {
        // disconnecting self from all groups:
        NSEnumerator *enumerator = [[self valueForKey:@"groups"] objectEnumerator];
        G3MessageGroup *group;
        while (group = [enumerator nextObject])
        {
            [self removeGroup:group];
        }
        
        [[NSManagedObjectContext threadContext] deleteObject:self];		
    }
}

BOOL messageReferencesOneOfThese(G3Message *aMessage, NSSet *someMessages)
/*" Assumes that there are no rings in references. "*/
{
    G3Message *reference = [aMessage reference];
    
    if (reference) {
        if (![someMessages containsObject:reference]) {
            return messageReferencesOneOfThese(reference, someMessages);
        }
        return YES;
    }
    // None found
    return NO;
}

- (NSSet *)subthreadWithMessage:(G3Message *)aMessage
{
    NSMutableSet *subthreadMessages = [NSMutableSet setWithObject:aMessage];
    NSEnumerator *enumerator;
    G3Message *message;
    
    enumerator = [[self messages] objectEnumerator];
    while (message = [enumerator nextObject])
    {
        if (messageReferencesOneOfThese(message, subthreadMessages))
        {
            [subthreadMessages addObject:message];
        }
    }
    
    return subthreadMessages;
}

- (G3Thread *)splitWithMessage:(G3Message *)aMessage
/*" Splits the receiver into two threads. Returns a thread containing aMessage and comments and removes these messages from the receiver. "*/
{
    G3Thread *newThread = [[[[self class] alloc] init] autorelease];
    NSEnumerator *enumerator;
    G3Message *message;
    
    enumerator = [[self subthreadWithMessage:aMessage] objectEnumerator];
    while (message = [enumerator nextObject])
    {
        [newThread addMessage:message];
    }

    // update numberOfMessages attribute:
    int newValue = [[self messages] count];
    [self setValue: [NSNumber numberWithInt:newValue] forKey:@"numberOfMessages"];
    
    if (newValue == 0)
    {
        // disconnecting self from all groups:
        NSEnumerator *enumerator = [[self valueForKey:@"groups"] objectEnumerator];
        G3MessageGroup *group;
        while (group = [enumerator nextObject])
        {
            [self removeGroup:group];
        }
        
        [[NSManagedObjectContext threadContext] deleteObject:self];		
    }
    
    return newThread;
}

- (void)mergeMessagesFromThread:(G3Thread *)otherThread
/*" Includes all messages from otherThread. otherThread is being deleted. "*/
{
    // put all messages from otherThread into self and remove otherThread
    G3Message *message;
    NSEnumerator *enumerator = [[otherThread messages] objectEnumerator];
    
    while (message = [enumerator nextObject])
    {
        [self addMessage:message];
    }
    
    /*
    // disconnecting another thread from all groups:
    enumerator = [[otherThread valueForKey:@"groups"] objectEnumerator];
    while (group = [enumerator nextObject])
    {
        [self removeGroup:group];
    }
     */

    
    [[NSManagedObjectContext threadContext] deleteObject:otherThread];		
}

/*
- (BOOL) validateForInsert: (NSError**) error
{
	int newValue = [[self messages] count];
	[self setValue: [NSNumber numberWithInt: newValue] forKey: @"numberOfMessages"];

	return [super validateForInsert: error];	
}
- (BOOL) validateForUpdate: (NSError**) error 
{
	int newValue = [[self messages] count];
	[self setValue: [NSNumber numberWithInt: newValue] forKey: @"numberOfMessages"];

	return [super validateForUpdate: error];	
}
*/

- (NSArray*) messagesByDate
{
    return [[[self messages] allObjects] sortedArrayByComparingAttribute: @"date"];
}

- (void) treeWalkFrom: (G3Message*) localRoot addTo: (NSMutableArray*) result
{
    [result addObject: localRoot];
    NSArray* comments = [localRoot commentsInThread: self];
    int i;
    int commentCount = [comments count];
    for (i=0; i<commentCount; i++) {
        [self treeWalkFrom: [comments objectAtIndex: i] addTo: result];
    }
}

- (NSArray*) messagesByTree
/* Returns an array containing the result of a depth first search over all tree roots. */
{
    NSSet *allMessages = [self messages];
    NSMutableArray* result = [NSMutableArray arrayWithCapacity: [allMessages count]];
    NSEnumerator *me = [allMessages objectEnumerator];
    G3Message *message;
    while (message = [me nextObject]) {
        if (![message reference]) {
            // Found a root message. Walk the tree and collect all nodes:
            [self treeWalkFrom: message addTo: result];
        }
    }
    return result;
}

/* as documentation of NSManagedObject suggests...no overriding of -description
- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ %@: %@", [super description], [self valueForKey: @"subject"], [self messages]];
}
*/

- (BOOL)containsSingleMessage
{
    return [self messageCount] == 1;
}

- (NSArray*) rootMessages
/*" Returns all messages without reference in the receiver. "*/
{
    NSMutableArray *result = [NSMutableArray array];
    NSEnumerator *me = [[self messages] objectEnumerator];
    G3Message *message;
    while (message = [me nextObject]) 
    {
        if (![message reference]) 
        {
            [result addObject:message];
        }
    }
    
    return result;
}

- (unsigned)commentDepthWithRoot:(G3Message *)root
{
    NSEnumerator *ce = [[root commentsInThread: self] objectEnumerator];
    G3Message *comment;
    unsigned result = 0;
    while (comment = [ce nextObject]) 
    {
        result = MAX(result, 1 + [self commentDepthWithRoot: comment]);
    }
    
    return result;
}

/*
- (unsigned) verticalOffsetForMessage: (G3Message*) aMessage
{
    return [[verticalOffsets objectForKey: aMessage] unsignedIntValue];
}

- (void) setVerticalOffset: (unsigned) offset forMessage: (G3Message*) aMessage
{
    [verticalOffsets setObject: [NSNumber numberWithUnsignedInt: offset] forKey: aMessage];
}
*/

- (unsigned)commentDepth
/*" Returns the the length of the longest comment chain in this thread. "*/
{
    NSEnumerator *re = [[self messages] objectEnumerator];
    G3Message *msg;
    unsigned result = 0;
    while (msg = [re nextObject]) 
    {
        result = MAX(result, [msg numberOfReferences]);
    }
    
    return result + 1;
}

- (BOOL)hasUnreadMessages
{
    NSEnumerator *enumerator;
    G3Message *message;
    
    enumerator = [[self messages] objectEnumerator];
    while (message = [enumerator nextObject]) 
    {
        if (![message hasFlags:OPSeenStatus]) 
        {
            return YES;
        }
    }
    
    return NO;
}

@end
