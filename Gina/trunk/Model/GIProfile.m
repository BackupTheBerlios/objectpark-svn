//
//  GIProfile.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 26.07.05.
//  Copyright 2005 The Objectpark Group. All rights reserved.
//

#import "GIProfile.h"
#import <Foundation/NSDebug.h>

#import "GIAccount.h"
#import "GIMessage.h"
#import "OPInternetMessage.h"
#import "NSString+MessageUtils.h"
#import "NSString+Extensions.h"
#import "NSArray+Extensions.h"
#import "NSError+Extensions.h"
#import "OPInternetMessage.h"
#import "GIUserDefaultsKeys.h"
#import "OPPersistence.h"

NSString *GIProfileDidChangNotification = @"GIProfileDidChangNotification";

@implementation GIProfile

+ (BOOL)cachesAllObjects
{
	return YES;
}

- (void)dealloc
{
	[cachedEmailAddresses release];
	[super dealloc];
}

// Accessors:

- (unsigned)sendDelay
{
	return sendDelay;
}

- (void)setSendDelay:(unsigned)aDelay
{
	[self willChangeValueForKey:@"sendDelay"];
	sendDelay = aDelay;
	[self didChangeValueForKey:@"sendDelay"];
}

- (NSString *)additionalAddresses
{
	return additionalAddresses;
}

- (void)setAdditionalAddresses:(NSString *)someAddresses
{
	[self willChangeValueForKey:@"additionalAddresses"];
	[additionalAddresses autorelease];
	additionalAddresses = [someAddresses copy];
	[self didChangeValueForKey:@"additionalAddresses"];
}

- (NSString *)defaultCc
{
	return defaultCc;
}

- (void)setDefaultCc:(NSString *)aString
{
	[self willChangeValueForKey:@"defaultCc"];
	[defaultCc autorelease];
	defaultCc = [aString copy];
	[self didChangeValueForKey:@"defaultCc"];
}

- (NSString *)defaultBcc
{
	return defaultBcc;
}

- (void)setDefaultBcc:(NSString *)aString
{
	[self willChangeValueForKey:@"defaultBcc"];
	[defaultBcc autorelease];
	defaultBcc = [aString copy];
	[self didChangeValueForKey:@"defaultBcc"];
}

- (NSString *)realname
{
	return realname;
}

- (void)setRealname:(NSString *)aString
{
	[self willChangeValueForKey:@"realname"];
	[realname autorelease];
	realname = [aString copy];
	[self didChangeValueForKey:@"realname"];
}

- (BOOL)enabled
{
	return enabled;
}

- (void)setEnabled:(BOOL)aBool
{
	[self willChangeValueForKey:@"enabled"];
	enabled = aBool;
	[self didChangeValueForKey:@"enabled"];
}

- (NSString *)defaultReplyTo
{
	return defaultReplyTo;
}

- (void)setDefaultReplyTo:(NSString *)aString
{
	[self willChangeValueForKey:@"defaultReplyTo"];
	[defaultReplyTo autorelease];
	defaultReplyTo = [aString copy];
	[self didChangeValueForKey:@"defaultReplyTo"];
}

- (NSString *)mailAddress
{
	return mailAddress;
}

- (void)setMailAddress:(NSString *)aString
{
	[self willChangeValueForKey:@"mailAddress"];
	[mailAddress autorelease];
	mailAddress = [aString copy];
	[self didChangeValueForKey:@"mailAddress"];
}

- (NSString *)organization
{
	return organization;
}

- (void)setOrganization:(NSString *)aString
{
	[self willChangeValueForKey:@"organization"];
	[organization autorelease];
	organization = [aString copy];
	[self didChangeValueForKey:@"organization"];
}

- (NSString *)name
{
	return name;
}

- (void)setName:(NSString *)aString
{
	[self willChangeValueForKey:@"name"];
	[name autorelease];
	name = [aString copy];
	[self didChangeValueForKey:@"name"];
}

- (NSAttributedString *)signature
{
	return signature;
}

- (void)setSignature:(NSAttributedString *)anAttributedString
{
	[self willChangeValueForKey:@"signature"];
	[signature autorelease];
	signature = [anAttributedString copy];
	[self didChangeValueForKey:@"signature"];
}

- (NSAttributedString *)messageTemplate
{
	return messageTemplate;
}

- (void)setMessageTemplate:(NSAttributedString *)anAttributedString
{
	[self willChangeValueForKey:@"messageTemplate"];
	[messageTemplate autorelease];
	messageTemplate = [anAttributedString copy];
	[self didChangeValueForKey:@"messageTemplate"];
}

- (GIAccount *)sendAccount
{
	return [[self context] objectForOID:sendAccountOID];
}

- (void)setSendAccount:(GIAccount *)anAccount
{
	if (sendAccountOID != [anAccount oid]) 
	{
		[self willChangeValueForKey:@"sendAccount"];		
		sendAccountOID = [anAccount oid];
		[self didChangeValueForKey:@"sendAccount"];
	}
}

- (OPFaultingArray *)messagesToSend
{
	if (!messagesToSend)
	{
		messagesToSend = [[OPFaultingArray alloc] init];
	}
	
	return messagesToSend;
}

- (BOOL)shouldSignNewMessagesByDefault
{
	return shouldSignNewMessagesByDefault;
}

- (void)setShouldSignNewMessagesByDefault:(BOOL)aBool
{
	[self willChangeValueForKey:@"shouldSignNewMessagesByDefault"];
	shouldSignNewMessagesByDefault = aBool;
	[self didChangeValueForKey:@"shouldSignNewMessagesByDefault"];
}

- (BOOL)shouldEncryptNewMessagesByDefault
{
	return shouldEncryptNewMessagesByDefault;
}

- (void)setShouldEncryptNewMessagesByDefault:(BOOL)aBool
{
	[self willChangeValueForKey:@"shouldEncryptNewMessagesByDefault"];
	shouldEncryptNewMessagesByDefault = aBool;
	[self didChangeValueForKey:@"shouldEncryptNewMessagesByDefault"];
}


- (BOOL)validateMailAddress:(NSString **)address error:(NSError **)outError
{
	if ([*address length] < 3) 
	{
		// illegal email address
		*outError = [NSError errorWithDomain:@"GIProfile" description:@"No valid email address has been set in the  selected profile."];
	}
	return *outError == nil;
}

/*" Returns all additional email addresses which are related of the receiver. "*/
- (NSArray *)allAdditionalEmailAddresses 
{
	if (!cachedEmailAddresses)
	{
		cachedEmailAddresses = [[[self valueForKey:@"additionalAddresses"] addressListFromEMailString] retain];
	}
	
    return cachedEmailAddresses;
}

+ (GIProfile *)guessedProfileForReplyingToMessage:(OPInternetMessage *)aMessage
/*" Tries to find a profile that matches the one meant by aMessage. Return nil if no profile could be guessed. "*/ 
{    
    // All addressees:
    NSArray *toList = [[aMessage bodyForHeaderField:@"To"] addressListFromEMailString];
    NSArray *ccList = [[aMessage bodyForHeaderField:@"Cc"] addressListFromEMailString];
    NSArray *addressList = ([ccList count] ? [toList arrayByAddingObjectsFromArray:ccList] : toList);

    NSEnumerator *enumerator = [[[OPPersistentObjectContext defaultContext] allObjectsOfClass:[GIProfile class]] objectEnumerator];
	GIProfile *profile;
    GIProfile *replyToCandidate = nil;
    while ((profile = [enumerator nextObject])) 
	{
        if ([[profile valueForKey:@"enabled"] boolValue]) 
		{
            NSString *email = [profile valueForKey:@"mailAddress"];
            NSString *replyTo = [profile valueForKey:@"defaultReplyTo"];
            NSEnumerator *addressEnumerator = [addressList objectEnumerator];
            NSString *address;
            
            while ((address = [addressEnumerator nextObject])) 
			{
                if (email && [email caseInsensitiveCompare:address] == NSOrderedSame) 
				{
                    return profile;
                }
                
                // try to match additional addresses:
                NSEnumerator *additionalEnumerator = [[profile allAdditionalEmailAddresses] objectEnumerator];
                NSString *additionalAddress;
                
                while (additionalAddress = [additionalEnumerator nextObject]) 
				{
                    if ([additionalAddress caseInsensitiveCompare:address] == NSOrderedSame) 
					{
                        return profile;
                    }
                }
                
                if (!replyToCandidate && replyTo && [replyTo caseInsensitiveCompare:address] == NSOrderedSame) {
                    replyToCandidate = profile;
                }
            }
        }
    }
    
    return replyToCandidate;
}

/*" Returns true if the given address is one of the known (present in any profile) user's addresses. "*/
+ (BOOL)isMyEmailAddress:(NSString *)anAddress 
{
	if (anAddress) 
	{
		@try 
		{
			anAddress = [anAddress addressFromEMailString]; // to be sure to have only the address part
			
			for (GIProfile *profile in [[OPPersistentObjectContext defaultContext] allObjectsOfClass:self])
			{
				if ([[[profile valueForKey:@"mailAddress"] addressFromEMailString] rangeOfString:anAddress options:NSCaseInsensitiveSearch].location != NSNotFound) 
				{
					return YES;
				}
				
				NSEnumerator *aaEnumerator = [[profile allAdditionalEmailAddresses] objectEnumerator];
				NSString *aAddress;
				
				while (aAddress = [aaEnumerator nextObject]) 
				{
					if ([[aAddress addressFromEMailString] rangeOfString:anAddress options:NSCaseInsensitiveSearch].location != NSNotFound) 
					{
						return YES;
					}
				}
			}
		} 
		@catch (id localException) 
		{
			return NO; // Expect our users to have correct email addresses.
		}
    }
    return NO;
}

// Default Profile stuff:

+ (GIProfile *)defaultProfile
{
	NSString *URLString = [[NSUserDefaults standardUserDefaults] objectForKey:DefaultProfileURLString];
	
	GIProfile *result = [[OPPersistentObjectContext defaultContext] objectWithURLString:URLString];
	
	if (! result) 
	{
		result = [[[OPPersistentObjectContext defaultContext] allObjectsOfClass:[GIProfile class]] anyObject];
		if (result) [self setDefaultProfile:result];
	}
	
	return result;
}

+ (void)setDefaultProfile:(GIProfile *)aProfile
{
	if (aProfile)
	{
#warning disabled while objectURLString is broken
//		[[NSUserDefaults standardUserDefaults] setObject:[aProfile objectURLString] forKey:DefaultProfileURLString];
	}
}

- (BOOL)isDefaultProfile
{
	return self == [[self class] defaultProfile];
}

- (void)makeDefaultProfile
{
	[[self class] setDefaultProfile:self];
}

- (void)didChangeValueForKey:(NSString *)key
{
	if ([key isEqualToString:@"additionalAddresses"])
	{
		[cachedEmailAddresses release];
		cachedEmailAddresses = nil;
	}
	
	[super didChangeValueForKey:key];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:GIProfileDidChangNotification object:self userInfo:[NSDictionary dictionaryWithObject:key forKey:@"key"]];
}

- (NSString *)realnameForSending
{
	static NSCharacterSet *charactersThatNeedQuotingSet = nil;
	static NSCharacterSet *quoteCharSet = nil;
	
	if (!charactersThatNeedQuotingSet)
	{
		charactersThatNeedQuotingSet = [[NSCharacterSet characterSetWithCharactersInString:@","] retain];
		quoteCharSet = [[NSCharacterSet characterSetWithCharactersInString:@"\""] retain];
	}
	
	NSString *result = [self valueForKey:@"realname"];
	if ([result rangeOfCharacterFromSet:charactersThatNeedQuotingSet].location != NSNotFound)
	{
		// needs quoting
		result = [NSString stringWithFormat:@"\"%@\"", [result stringByRemovingCharactersFromSet:quoteCharSet]];
	}
	
	return result;
}

- (id)initWithCoder:(NSCoder *)coder
{
	enabled = [coder decodeBoolForKey:@"enabled"];
	shouldSignNewMessagesByDefault = [coder decodeBoolForKey:@"shouldSignNewMessagesByDefault"];
	shouldEncryptNewMessagesByDefault = [coder decodeBoolForKey:@"shouldEncryptNewMessagesByDefault"];
	sendDelay = [coder decodeInt32ForKey:@"sendDelay"];
	additionalAddresses = [coder decodeObjectForKey:@"additionalAddresses"];
	defaultCc = [coder decodeObjectForKey:@"defaultCc"];
	defaultBcc = [coder decodeObjectForKey:@"defaultBcc"];
	realname = [coder decodeObjectForKey:@"realname"];
	defaultReplyTo = [coder decodeObjectForKey:@"defaultReplyTo"];
	mailAddress = [coder decodeObjectForKey:@"mailAddress"];
	organization = [coder decodeObjectForKey:@"organization"];
	name = [coder decodeObjectForKey:@"name"];
	signature = [coder decodeObjectForKey:@"signature"];
	messageTemplate = [coder decodeObjectForKey:@"messageTemplate"];
	sendAccountOID = [coder decodeOIDForKey:@"sendAccount"];
	messagesToSend = [coder decodeObjectForKey:@"messagesToSend"];

	return self;
}

- (void)encodeWithCoder:(NSCoder*) coder
{
	[coder encodeObject:additionalAddresses forKey:@"additionalAddresses"];
	[coder encodeObject:defaultCc forKey:@"defaultCc"];
	[coder encodeObject:defaultBcc forKey:@"defaultBcc"];
	[coder encodeObject:realname forKey:@"realname"];
	[coder encodeObject:defaultReplyTo forKey:@"defaultReplyTo"];
	[coder encodeObject:mailAddress forKey:@"mailAddress"];
	[coder encodeObject:organization forKey:@"organization"];
	[coder encodeObject:name forKey:@"name"];
	[coder encodeObject:signature forKey:@"signature"];
	[coder encodeObject:messageTemplate forKey:@"messageTemplate"];
	[coder encodeObject:messagesToSend forKey:@"messagesToSend"];
	[coder encodeOID:sendAccountOID forKey:@"sendAccount"];
	
	[coder encodeInt32:sendDelay forKey:@"sendDelay"];
	[coder encodeBool:enabled forKey:@"enabled"];
	[coder encodeBool:shouldSignNewMessagesByDefault forKey:@"shouldSignNewMessagesByDefault"];
	[coder encodeBool:shouldEncryptNewMessagesByDefault forKey:@"shouldEncryptNewMessagesByDefault"];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ '%@'", [super description], [self valueForKey:@"name"]];
}

@end


//#import <GPGME/GPGME.h>

@implementation GIProfile (OpenPGP)

- (NSArray*) matchingKeys
{
	return [NSArray array];
	
/*
	GPGContext* context = nil;
	NSArray* result = nil;
	
	@try {
		if ([[[GPGEngine availableEngines] lastObject] version]) {
			context = [[GPGContext alloc] init];
			NSString *emailAddress = [[self valueForKey:@"mailAddress"] addressFromEMailString];
			result = [[context keyEnumeratorForSearchPattern:[NSString stringWithFormat:@"<%@>", emailAddress] secretKeysOnly:YES] allObjects];
		}
	} @catch (id localException) {
		NSLog(@"Exception while retrieving keys:%@", localException);
		return [NSArray array];
	} @finally {
		[context stopKeyEnumeration];
		[context release];
	}
	
	return result;
 */
}

@end
