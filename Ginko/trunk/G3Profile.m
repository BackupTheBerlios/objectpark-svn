//
//  G3Profile.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 16.12.04.
//  Copyright 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "G3Profile.h"
#import "GIAccount.h"
#import "GIMessage.h"
#import "NSString+MessageUtils.h"
#import "NSArray+Extensions.h"
#import "OPInternetMessage.h"
#import "OPPersistentObject+Extensions.h"

@implementation G3Profile

+ (NSArray*) allObjects
/*" Returns all profile instances, assuring there is at least one (by creating it). "*/
{    
    NSArray *result;
    
    @synchronized(self)
    {
        result = [super allObjects];
        
        if (![result count]) {
            G3Profile *profile = [[[self alloc] init] autorelease];
            [profile setValue: @"Dummy Profile" forKey: @"name"];
            [profile setValue: [NSNumber numberWithBool: NO] forKey: @"enabled"];
            [profile setValue: @"dummy@profile.org" forKey: @"emailAddress"];
            result = [self allObjects];
        }
        
        result = [[result copy] autorelease];
    }
    return result;
}

+ (void) setProfiles:(NSArray*) someProfiles
{
   // [profiles autorelease];
   // profiles = [someProfiles retain];
}

+ (G3Profile*) defaultProfile
/*" Returns the default Profile. "*/
{
    return [[self allObjects] firstObject]; // dth: why should this work?
}

- (id)init
/*" Adds the reciever to the default managed object context. "*/
{
    return [self initWithManagedObjectContext:[NSManagedObjectContext threadContext]];
}

+ (BOOL) isMyEmailAddress: (NSString*) anAddress
{
    NSEnumerator *enumerator;
    G3Profile *profile;
    
    @try {
        anAddress = [anAddress addressFromEMailString]; // to be sure to have only the address part
        
        enumerator = [[G3Profile allObjects] objectEnumerator];
        while (profile = [enumerator nextObject]) {
            if ([[[profile emailAddress] addressFromEMailString] rangeOfString:anAddress options:NSCaseInsensitiveSearch] .location != NSNotFound) {
                return YES;
            }
        }
    } @catch (NSException* localException) {
        return NO; // Expect our users to have correct email addresses.
    }
    
    return NO;
}

+ (G3Profile *)guessedProfileForReplyingToMessage: (OPInternetMessage*) aMessage
/*" Tries to find a profile that matches the one meant by aMessage. Return nil if no profile could be guessed. "*/ 
{
    NSArray *toList, *ccList, *addressList;
    NSEnumerator *enumerator;
    G3Profile *profile;
    G3Profile* replyToCandidate = nil;
    
    // all addressees:
    toList = [[aMessage bodyForHeaderField: @"To"] addressListFromEMailString];
    ccList = [[aMessage bodyForHeaderField: @"Cc"] addressListFromEMailString];
    
    if ([ccList count]) {
        addressList = [toList arrayByAddingObjectsFromArray:ccList];
    } else {
        addressList = toList;
    }
            
    enumerator = [[self allObjects] objectEnumerator];
    while ((profile = [enumerator nextObject])) {
		
        if ([[profile valueForKey: @"enabled"] boolValue]) {
            NSString *email = [profile emailAddress];
            NSString *replyTo = [profile valueForKey: @"replyToAddress"];
            NSEnumerator *addressEnumerator = [addressList objectEnumerator];
            NSString *address;
            
            while ((address = [addressEnumerator nextObject])) {
                if (email && [email caseInsensitiveCompare:address] == NSOrderedSame) {
                    return profile;
                }
                
                if (!replyToCandidate && replyTo && [replyTo caseInsensitiveCompare:address] == NSOrderedSame) {
                    replyToCandidate = profile;
                }
            }
        }
    }
    
    return replyToCandidate;
}

- (NSString*) name
{
    [self willAccessValueForKey: @"name"];
    id result = [self primitiveValueForKey: @"name"];
    [self didAccessValueForKey: @"name"];
    return result;
}

- (void) setName: (NSString*) aString
{
    [self willChangeValueForKey: @"name"];
    [self setPrimitiveValue: aString forKey: @"name"];
    [self didChangeValueForKey: @"name"];
}

- (NSString*) realname
{
    [self willAccessValueForKey: @"realname"];
    id result = [self primitiveValueForKey: @"realname"];
    [self didAccessValueForKey: @"realname"];
    return result;
}

- (void) setRealname: (NSString*) aString
{
    [self willChangeValueForKey: @"realname"];
    [self setPrimitiveValue: aString forKey: @"realname"];
    [self didChangeValueForKey: @"realname"];
}

- (NSString*) emailAddress
{
    [self willAccessValueForKey: @"mailaddress"];
    id result = [self primitiveValueForKey: @"mailaddress"];
    [self didAccessValueForKey: @"mailaddress"];
    return result;
}

- (void) removeValue: (id) value forKey: (NSString*) key // for forward compatibility only
{
	NSParameterAssert([key isEqualToString: @"messagesToSend"]);
	[self removeMessageToSend: value];
}

- (void) setEmailAddress: (NSString*) aString
{
    [self willChangeValueForKey: @"mailaddress"];
    [self setPrimitiveValue:aString forKey: @"mailaddress"];
    [self didChangeValueForKey: @"mailaddress"];
}

- (NSString*) replyToAddress
{
    [self willAccessValueForKey: @"defaultReplyTo"];
    id result = [self primitiveValueForKey: @"defaultReplyTo"];
    [self didAccessValueForKey: @"defaultReplyTo"];
    return result;
}

- (void) setReplyToAddress: (NSString*) aString
{
    [self willChangeValueForKey: @"defaultReplyTo"];
    [self setPrimitiveValue:aString forKey: @"defaultReplyTo"];
    [self didChangeValueForKey: @"defaultReplyTo"];
}

- (NSString*) organization
{
    return [self primitiveValueForKey: @"organization"];
}

- (void) setOrganization: (NSString*) aString
{
    [self willChangeValueForKey: @"organization"];
    [self setPrimitiveValue:aString forKey: @"organization"];
    [self didChangeValueForKey: @"organization"];
}

- (NSData*) signature
{
    return [self primitiveValueForKey: @"signature"];
}

- (void) setSignature: (NSData*) aSig
{
    [self willChangeValueForKey: @"signature"];
    [self setPrimitiveValue:aSig forKey: @"signature"];
    [self didChangeValueForKey: @"signature"];
}


- (NSData*) messageTemplate
{
    [self willAccessValueForKey: @"messageTemplate"];
    id result = [self primitiveValueForKey: @"messageTemplate"];
    [self didAccessValueForKey: @"messageTemplate"];
    return result;
}

- (void) setMessageTemplate: (NSData*) aTemp
{
    [self willChangeValueForKey: @"messageTemplate"];
    [self setPrimitiveValue:aTemp forKey: @"messageTemplate"];
    [self didChangeValueForKey: @"messageTemplate"];
}

- (void) addMessageToSend: (G3Message*) aMessage 
{    
    NSSet *changedObjects = [[NSSet alloc] initWithObjects:&aMessage count:1];
    
    [self willChangeValueForKey: @"messagesToSend" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changedObjects];
    
    [[self primitiveValueForKey: @"messagesToSend"] addObject:aMessage];
    
    [self didChangeValueForKey: @"messagesToSend" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changedObjects];
    
    [changedObjects release];
}

- (void) removeMessageToSend: (G3Message*) aMessage 
{
    NSSet *changedObjects = [[NSSet alloc] initWithObjects:&aMessage count:1];
    
    [self willChangeValueForKey: @"messagesToSend" withSetMutation:NSKeyValueMinusSetMutation usingObjects:changedObjects];
    
    [[self primitiveValueForKey: @"messagesToSend"] removeObject:aMessage];
    
    [self didChangeValueForKey: @"messagesToSend" withSetMutation:NSKeyValueMinusSetMutation usingObjects:changedObjects];
    
    [changedObjects release];
}


@end
