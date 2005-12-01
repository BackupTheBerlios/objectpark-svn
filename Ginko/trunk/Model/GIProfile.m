//
//  GIProfile.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 26.07.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "GIProfile.h"
#import <Foundation/NSDebug.h>

#import "GIAccount.h"
#import "GIMessage.h"
#import "NSString+MessageUtils.h"
#import "NSArray+Extensions.h"
#import "OPInternetMessage.h"
#import "OPPersistentObject+Extensions.h"

@implementation GIProfile


+ (NSString*) databaseProperties
{
	return 
	@"{"
	@"  TableName = ZPROFILE;"
	@"  CreateStatements = (\""
	@"  CREATE TABLE ZPROFILE (Z_ENT INTEGER, Z_PK INTEGER PRIMARY KEY, Z_OPT INTEGER, ZDEFAULTCC VARCHAR, ZDEFAULTBCC VARCHAR, ZENABLED INTEGER, ZDEFAULTREPLYTO VARCHAR, ZMAILADDRESS VARCHAR, ZORGANIZATION VARCHAR, ZNAME VARCHAR, ZSIGNATURE BLOB, ZMESSAGETEMPLATE BLOB, ZREALNAME VARCHAR, ZSENDACCOUNT INTEGER);"
	@"  \");"
	@""
	@"}";
}

+ (NSString*) persistentAttributesPlist
{
	return 
	@"{"
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
	@"sendAccount = {ColumnName = ZSENDACCOUNT; AttributeClass = GIAccount;};"
	@"messagesToSend = {AttributeClass = GIMessage; QueryString =\"select ZMESSAGE.ROWID from ZMESSAGE where ZPROFILE=?\";};"
	@"}";
}

+ (NSArray*) allObjects
	/*" Returns all profile instances, assuring there is at least one (by creating it). "*/
{    
    NSArray* result;
#warning Todo: Cache +[GIProfile allObjects] for better performance of e.g. -isMyEmailAddress!
    @synchronized(self)
    {
        result = [[self allObjectsEnumerator] allObjects];
        
        if (![result count]) {
            GIProfile* profile = [[[self alloc] init] autorelease];
            [profile setValue: @"Dummy Profile" forKey: @"name"];
            [profile setValue: [NSNumber numberWithBool: NO] forKey: @"enabled"];
            [profile setValue: @"dummy@replace.this" forKey: @"mailAddress"];
			[profile insertIntoContext: [OPPersistentObjectContext defaultContext]]; // make persistent.
			
			[[OPPersistentObjectContext defaultContext] saveChanges];
			
			result = [[super allObjectsEnumerator] allObjects];
        }
        
        result = [[result copy] autorelease];
    }
    return result;
}

- (BOOL) validateMailAddress: (NSString**) address error: (NSError**) outError
{
	if ([*address length]<3) {
		// illegal email address
		*outError = [NSError errorWithDomain: @"GIProfile" description: @"No valid email address has been set in the  selected profile."];
	}
	return  *outError == nil;
}

+ (GIProfile*) defaultProfile
	/*" Returns the default Profile. "*/
{
    return [[self allObjects] firstObject]; // dth: why should this work?
}

+ (GIProfile*) guessedProfileForReplyingToMessage: (OPInternetMessage*) aMessage
	/*" Tries to find a profile that matches the one meant by aMessage. Return nil if no profile could be guessed. "*/ 
{    
    // All addressees:
    NSArray* toList = [[aMessage bodyForHeaderField: @"To"] addressListFromEMailString];
    NSArray* ccList = [[aMessage bodyForHeaderField: @"Cc"] addressListFromEMailString];
    NSArray* addressList = ([ccList count] ? [toList arrayByAddingObjectsFromArray:ccList] : toList);

    NSEnumerator* enumerator = [[self allObjects] objectEnumerator];
	GIProfile* profile;
    GIProfile* replyToCandidate = nil;
    while ((profile = [enumerator nextObject])) {
		
        if ([[profile valueForKey: @"enabled"] boolValue]) {
            NSString* email = [profile mailAddress];
            NSString* replyTo = [profile valueForKey: @"defaultReplyTo"];
            NSEnumerator* addressEnumerator = [addressList objectEnumerator];
            NSString* address;
            
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

+ (BOOL) isMyEmailAddress: (NSString*) anAddress
{
    NSEnumerator *enumerator;
    GIProfile *profile;
    
    @try {
        anAddress = [anAddress addressFromEMailString]; // to be sure to have only the address part
        
        enumerator = [[GIProfile allObjects] objectEnumerator];
        while (profile = [enumerator nextObject]) {
            if ([[[profile mailAddress] addressFromEMailString] rangeOfString: anAddress options:NSCaseInsensitiveSearch] .location != NSNotFound) {
                return YES;
            }
        }
    } @catch (NSException* localException) {
        return NO; // Expect our users to have correct email addresses.
    }
    
    return NO;
}


- (NSString*) mailAddress
{
    [self willAccessValueForKey: @"mailAddress"];
    id result = [self primitiveValueForKey: @"mailAddress"];
    [self didAccessValueForKey: @"mailAddress"];
    return result;
}

@end
