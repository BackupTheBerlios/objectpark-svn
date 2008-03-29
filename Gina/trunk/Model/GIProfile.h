//
//  GIProfile.h
//  Gina
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
	
	NSUInteger sendDelay;
	NSString *additionalAddresses;
	NSString *defaultCc;
	NSString *defaultBcc;
	NSString *realname;
	BOOL enabled;
	NSString *defaultReplyTo;
	NSString *mailAddress;
	NSString *organization;
	NSString *name;
	NSAttributedString *signature;
	NSAttributedString *messageTemplate;
	OID sendAccountOID;
	OPFaultingArray *messagesToSend;
	BOOL shouldSignNewMessagesByDefault;
	BOOL shouldEncryptNewMessagesByDefault;	
}

@property (readwrite) unsigned sendDelay;
@property (readwrite, copy) NSString *additionalAddresses;
@property (readwrite, copy) NSString *defaultCc;
@property (readwrite, copy) NSString *defaultBcc;
@property (readwrite, copy) NSString *realname;
@property (readwrite) BOOL enabled;
@property (readwrite, copy) NSString *defaultReplyTo;
@property (readwrite, copy) NSString *mailAddress;
@property (readwrite, copy) NSString *organization;
@property (readwrite, copy) NSString *name;
@property (readwrite, copy) NSAttributedString *signature;
@property (readwrite, copy) NSAttributedString *messageTemplate;
@property (readwrite, assign) GIAccount *sendAccount;
@property (readonly) OPFaultingArray *messagesToSend;
@property (readwrite) BOOL shouldSignNewMessagesByDefault;
@property (readwrite) BOOL shouldEncryptNewMessagesByDefault;	

/*" Accessing profiles "*/
+ (GIProfile *)sendProfileForMessage:(GIMessage *)aMessage;
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