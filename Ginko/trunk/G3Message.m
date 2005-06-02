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

+ (id)messageWithTransferData:(NSData *)someTransferData
/*" Returns a new message with the given transfer data someTransferData in the managed object context aContext. If message is a dupe, the message not inserted into the context and a GIDupeMessageException is raised. "*/
{
    id result = nil;
    OPInternetMessage *internetMessage = [[OPInternetMessage alloc] initWithTransferData:someTransferData];
    
    if ([self messageForMessageId:[internetMessage messageId]])
    {
        [internetMessage autorelease];
        [[NSException exceptionWithName:GIDupeMessageException reason:[NSString stringWithFormat:@"Dupe for message id %@ detected.", [internetMessage messageId]] userInfo:[NSDictionary dictionaryWithObject:someTransferData forKey:@"transferData"]] raise];        
    }
    
    // Create a new message in the default context:
    result = [[[G3Message alloc] initWithManagedObjectContext:[NSManagedObjectContext defaultContext]] autorelease];
    
    //NSString* fromHeader = [msg bodyForHeaderField: @"from"];
    NSString *fromHeader = [internetMessage fromWithFallback:YES];
    
    [result setValue:someTransferData forKey:@"transferData"];
    [result setValue:[internetMessage messageId] forKey:@"messageId"];  
    [result setValue:[internetMessage normalizedSubject] forKey:@"subject"];
    [result setValue:[fromHeader realnameFromEMailStringWithFallback] forKey:@"author"];
    [result setValue:[internetMessage date] forKey:@"date"];
    
    [internetMessage release];
    
    // Note that this method operates on the encoded header field. It's OK because email
    // addresses are 7bit only.
    if ([G3Profile isMyEmailAddress:fromHeader])
    {
        [result addFlags:OPIsFromMeStatus];
    }
    
    return result;
}


- (NSData *)transferData
{
	return [self valueForKeyPath: @"messageData.transferData"];
}

- (void) setTransferData: (NSData*) newData
{
    NSManagedObjectContext *context = [self managedObjectContext];
    NSEntityDescription *entity = [[[[context persistentStoreCoordinator] managedObjectModel] entitiesByName] objectForKey:@"MessageData"];
    NSManagedObject* messageData = [[[NSManagedObject alloc] initWithEntity:entity insertIntoManagedObjectContext: context] autorelease];
    
    [messageData setValue: newData forKey: @"transferData"];
    [self setValue: messageData forKey: @"messageData"];
}

- (NSString *)messageId
{
    [self willAccessValueForKey:@"messageId"];
    id result = [self primitiveValueForKey:@"messageId"];
    [self didAccessValueForKey:@"messageId"];
    return result;
}

- (unsigned)flags
{
    unsigned result;
    
    [self willAccessValueForKey:@"flags"];
    result = [[self primitiveValueForKey:@"flags"] intValue];
    [self didAccessValueForKey:@"flags"];
    return result;
}

- (void)setFlags:(unsigned)someFlags
{
    [self willChangeValueForKey:@"flags"];
    [self setPrimitiveValue:[NSNumber numberWithInt:someFlags] forKey:@"flags"];
    [self didChangeValueForKey:@"flags"];
}

- (BOOL)hasFlag:(unsigned)flag
{
    int flags = [self flags];
    return (flag & flags) != 0;
}

- (void)addFlags:(unsigned)someFlags
{
    int flags = [self flags];
    if (someFlags | flags !=flags)
    {
        [self setFlags:(flags | someFlags)];
    }
}

- (void)removeFlags:(unsigned)someFlags
{
    int flags = [self flags];
    
    if ((flags & (~someFlags)) != flags)
    {
        [self setFlags:(flags & (~someFlags))];
    }
}

/*
- (void) setFlag: (unsigned) flag to: (BOOL) value
{
	int flags = [[self valueForKey: @"flag"] intValue];
	if ((((1<<flag) & flags) != 0) !=value) {
		[self setValue: [NSNumber numberWithInt: (flags | (1<<flag))] forKey: @"flags"];
	}
}
*/

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

/* as documentation of NSManagedObject suggests...no overriding of -description
- (NSString*) description
{
    return [NSString stringWithFormat: @"%@, Subject: '%@', Author: '%@', Date: '%@'", [super description], [self valueForKey: @"subject"], [self valueForKey: @"author"], [self valueForKey: @"date"]];
}
*/

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



- (BOOL) isDummy
{
    return [self valueForKey:@"transferData"] == nil;
}


- (BOOL) isSeen
{
    return [self hasFlag: OPSeenStatus];
}

- (void) setSeen: (BOOL) isSeen
{
	if (isSeen)
		[self addFlags: OPSeenStatus];
	else
		[self removeFlags: OPSeenStatus];
}

- (BOOL) isListMessage
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

- (BOOL) isFromMe
/*" Returns YES, if the from: header contains one of my SMTP addresses configured. "*/
{
	return [self hasFlag: OPIsFromMeStatus];
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

- (OPInternetMessage*) internetMessage
{
    id transferData = [self valueForKey: @"transferData"];
    
    if (transferData) {
        if ([transferData isKindOfClass: [NSString class]]) { // only for dummy backend
            transferData = [transferData dataUsingEncoding: NSASCIIStringEncoding allowLossyConversion: YES];
        }
        return [[[OPInternetMessage alloc] initWithTransferData: transferData] autorelease];
    }
    return nil; // hamma nit
}



@end
