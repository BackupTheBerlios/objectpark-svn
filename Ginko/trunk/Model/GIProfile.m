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
#import "NSString+MessageUtils.h"
#import "NSArray+Extensions.h"
#import "OPInternetMessage.h"
#import "OPPersistentObject+Extensions.h"
#import "GIUserDefaultsKeys.h"

NSString *GIProfileDidChangNotification = @"GIProfileDidChangNotification";

@implementation GIProfile

+ (NSString*) databaseProperties
{
	return 
	@"{"
	@"  TableName = ZPROFILE;"
	@"  CacheAllObjects = 1;"
	@"  CreateStatements = (\""
	@"  CREATE TABLE ZPROFILE (Z_ENT INTEGER, Z_PK INTEGER PRIMARY KEY, Z_OPT INTEGER, ZSENDDELAY INTEGER, ZADDITIONALADDRESSES VARCHAR, ZDEFAULTCC VARCHAR, ZDEFAULTBCC VARCHAR, ZENABLED INTEGER, ZDEFAULTREPLYTO VARCHAR, ZMAILADDRESS VARCHAR, ZORGANIZATION VARCHAR, ZNAME VARCHAR, ZSIGNATURE BLOB, ZMESSAGETEMPLATE BLOB, ZREALNAME VARCHAR, ZSENDACCOUNT INTEGER, ZSIGNNEW INTEGER, ZENCRYPTNEW INTEGER);"
	@"  \");"
	@""
	@"}";
}

+ (NSString *)persistentAttributesPlist
{
	return 
	@"{"
	@"sendDelay = {ColumnName = ZSENDDELAY; AttributeClass = NSNumber;};"
    @"additionalAddresses = {ColumnName = ZADDITIONALADDRESSES; AttributeClass = NSString;};"
	@"defaultCc = {ColumnName = ZDEFAULTCC; AttributeClass = NSString;};"
	@"defaultBcc = {ColumnName = ZDEFAULTBCC; AttributeClass = NSString;};"
	@"realname = {ColumnName = ZREALNAME; AttributeClass = NSString;};"
	@"enabled = {ColumnName = ZENABLED; AttributeClass = NSNumber;};"
	@"defaultReplyTo = {ColumnName = ZDEFAULTREPLYTO; AttributeClass = NSString;};"
	@"mailAddress = {ColumnName = ZMAILADDRESS; AttributeClass = NSString;};"
	@"organization = {ColumnName = ZORGANIZATION; AttributeClass = NSString;};"
	@"name = {ColumnName = ZNAME; AttributeClass = NSString;};"
	@"signature = {ColumnName = ZSIGNATURE; AttributeClass = NSAttributedString;};"
	@"messageTemplate = {ColumnName = ZMESSAGETEMPLATE; AttributeClass = NSAttributedString;};"
	@"sendAccount = {InverseRelationshipKey = profiles; ColumnName = ZSENDACCOUNT; AttributeClass = GIAccount;};"
	@"messagesToSend = {InverseRelationshipKey = sendProfile; AttributeClass = GIMessage; QueryString =\"select ZMESSAGE.ROWID from ZMESSAGE where ZPROFILE=?1\";};"
	@"shouldSignNewMessagesByDefault = {ColumnName = ZSIGNNEW; AttributeClass = NSNumber;};"
	@"shouldEncryptNewMessagesByDefault = {ColumnName = ZENCRYPTNEW; AttributeClass = NSNumber;};"
	@"}";
}

+ (NSArray *)allObjects
/*" Returns all profile instances, assuring there is at least one (by creating it). The array returned is sorted by name. "*/
{    
    OPFaultingArray* result;
    @synchronized(self) {
		
		while (![(result = (OPFaultingArray*)[super allObjects]) count]) {
            GIProfile* profile = [[[self alloc] init] autorelease];
            [profile setValue:@"Dummy Profile" forKey:@"name"];
            [profile setValue:nil forKey:@"enabled"];
            [profile setValue:@"somename@domain.org" forKey:@"mailAddress"];
			[profile insertIntoContext: [OPPersistentObjectContext defaultContext]]; // make persistent.
			
			[[OPPersistentObjectContext defaultContext] saveChanges];
        } 
		//[result sortByComparingAttribute: @"name"];
        
	}
    return [result sortedArrayByComparingAttribute: @"name"]; // improve by making result sorted!
}

- (void)dealloc
{
	[cachedEmailAddresses release];
	[super dealloc];
}

- (BOOL)validateMailAddress:(NSString **)address error:(NSError **)outError
{
	if ([*address length] < 3) {
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

    NSEnumerator *enumerator = [[self allObjects] objectEnumerator];
	GIProfile *profile;
    GIProfile *replyToCandidate = nil;
    while ((profile = [enumerator nextObject])) {
        if ([[profile valueForKey:@"enabled"] boolValue]) {
            NSString *email = [profile valueForKey:@"mailAddress"];
            NSString *replyTo = [profile valueForKey:@"defaultReplyTo"];
            NSEnumerator *addressEnumerator = [addressList objectEnumerator];
            NSString *address;
            
            while ((address = [addressEnumerator nextObject])) {
                if (email && [email caseInsensitiveCompare:address] == NSOrderedSame) {
                    return profile;
                }
                
                // try to match additional addresses:
                NSEnumerator *additionalEnumerator = [[profile allAdditionalEmailAddresses] objectEnumerator];
                NSString *additionalAddress;
                
                while (additionalAddress = [additionalEnumerator nextObject]) {
                    if ([additionalAddress caseInsensitiveCompare:address] == NSOrderedSame) {
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
		NSEnumerator *enumerator;
		GIProfile *profile;
		
		@try 
		{
			anAddress = [anAddress addressFromEMailString]; // to be sure to have only the address part
			
			enumerator = [[GIProfile allObjects] objectEnumerator];
			while (profile = [enumerator nextObject]) 
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
	
	GIProfile *result = [[OPPersistentObjectContext defaultContext] objectWithURLString:URLString resolve: YES];
	
	if (! result) result = [[GIProfile allObjects] firstObject];
	
	return result;
}

+ (void)setDefaultProfile:(GIProfile *)aProfile
{
	[[NSUserDefaults standardUserDefaults] setObject:[aProfile objectURLString] forKey:DefaultProfileURLString];
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

@end


#import <GPGME/GPGME.h>

@implementation GIProfile (OpenPGP)

- (NSArray*) matchingKeys
{
	GPGContext* context = nil;
	NSArray* result = nil;
	
	@try {
		if ([[[GPGEngine availableEngines] lastObject] version]) {
			context = [[GPGContext alloc] init];
			NSString *emailAddress = [[self valueForKey: @"mailAddress"] addressFromEMailString];
			result = [[context keyEnumeratorForSearchPattern: [NSString stringWithFormat:@"<%@>", emailAddress] secretKeysOnly: YES] allObjects];
		}
	} @catch (id localException) {
		NSLog(@"Exception while retrieving keys: %@", localException);
		return [NSArray array];
	} @finally {
		[context stopKeyEnumeration];
		[context release];
	}
	
	return result;
}

@end
