//
//  G3Thread.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 02.12.04.
//  Copyright 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "G3Thread.h"
#import "G3Message.h"
#import "NSManagedObjectContext+Extensions.h"
#import "NSArray+Extensions.h"

@implementation G3Thread


- (id) init
/*" Adds the reciever to the default managed object context. "*/
{
	return [self initWithManagedObjectContext: [NSManagedObjectContext defaultContext]];
}



+ (G3Thread*) thread
/*" Creates a new persistent thread in the default managed object context. "*/
{	
	return [[[self alloc] init] autorelease];
}

- (unsigned) messageCount
{
    return (unsigned)[[self valueForKey: @"numberOfMessages"] intValue]; 
}


- (NSSet*) messages
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

- (void)removeMessage:(G3Message *)aMessage
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
}

BOOL messageReferencesOneOfThese(G3Message *aMessage, NSSet *someMessages)
/*" Assumes that there are no rings in references. "*/
{
    G3Message *reference = [aMessage reference];
    
    if (reference)
    {
        if ([someMessages containsObject:reference]) 
        {
            return YES;
        }
        else
        {
            return messageReferencesOneOfThese(reference, someMessages);
        }
    }
    
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
    
    return newThread;
}

- (void)mergeMessagesFromThread:(G3Thread *)anotherThread
/*" Includes all messages from anotherThread. "*/
{
    
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

- (NSString*) description
{
    return [NSString stringWithFormat: @"%@ %@: %@", [super description], [self valueForKey: @"subject"], [self messages]];
}

- (BOOL) containsSingleMessage
{
    return [self messageCount] == 1;
}

- (NSArray*) rootMessages
/*" Returns all messages without reference in the receiver. "*/
{
    NSMutableArray* result = [NSMutableArray array];
    NSEnumerator* me = [[self messages] objectEnumerator];
    G3Message* message;
    while (message = [me nextObject]) {
        if (![message reference]) {
            [result addObject: message];
        }
    }
    return result;
}

- (unsigned) commentDepthWithRoot: (G3Message*) root
{
    NSEnumerator* ce = [[root commentsInThread: self] objectEnumerator];
    G3Message* comment;
    unsigned result = 0;
    while (comment = [ce nextObject]) {
        result = MAX(result, 1+[self commentDepthWithRoot: comment]);
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

- (unsigned) commentDepth
/*" Returns the the length of the longest comment chain in this thread. "*/
{
    NSEnumerator* re = [[self messages] objectEnumerator];
    G3Message* msg;
    unsigned result = 0;
    while (msg = [re nextObject]) {
        result = MAX(result, [msg numberOfReferences]);
    }
    return result+1;
}

- (BOOL) hasUnreadMessages
{
    NSEnumerator *enumerator;
    G3Message *message;
    
    enumerator = [[self messages] objectEnumerator];
    while (message = [enumerator nextObject]) {
        if (![message isSeen]) {
            return YES;
        }
    }
    
    return NO;
}

@end
