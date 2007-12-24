//
//  GIProfile.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 26.07.05.
//  Copyright 2005 The Objectpark Group. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "OPPersistentObject.h"

@class OPInternetMessage;
@class GIAccount;
@class GIMessage;
@class OPFaultingArray;

@interface GIProfile : OPPersistentObject 
{
	NSArray *cachedEmailAddresses;
	
	unsigned sendDelay;
	NSString* additionalAddresses;
	NSString* defaultCc;
	NSString* defaultBcc;
	NSString* realname;
	BOOL enabled;
	NSString* defaultReplyTo;
	NSString* mailAddress;
	NSString* organization;
	NSString* name;
	NSAttributedString* signature;
	NSAttributedString* messageTemplate;
	OID sendAccountOID;
	OPFaultingArray* messagesToSend;
	BOOL shouldSignNewMessagesByDefault;
	BOOL shouldEncryptNewMessagesByDefault;	
}

/*" Accessing profiles "*/

+ (GIProfile *)guessedProfileForReplyingToMessage:(OPInternetMessage *)aMessage;

/*" Utility methods "*/
+ (BOOL)isMyEmailAddress:(NSString *)aString;

/*" Default Profile "*/
+ (GIProfile *)defaultProfile;
+ (void)setDefaultProfile:(GIProfile *)aProfile;
- (BOOL)isDefaultProfile;
- (void)makeDefaultProfile;

- (NSString *)realnameForSending;

@end

extern NSString *GIProfileDidChangNotification;

@interface GIProfile (OpenPGP)
- (NSArray *)matchingKeys;
@end