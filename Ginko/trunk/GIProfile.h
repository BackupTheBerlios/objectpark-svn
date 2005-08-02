//
//  GIProfile.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 26.07.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OPPersistentObject.h"



@class OPInternetMessage;
@class GIAccount;
@class GIMessage;

@interface GIProfile : OPPersistentObject {
	
}

+ (NSArray*) profiles;
+ (void)setProfiles:(NSArray *)someProfiles;
+ (GIProfile *)defaultProfile;
+ (GIProfile *)guessedProfileForReplyingToMessage:(OPInternetMessage *)aMessage;

+ (BOOL)isMyEmailAddress:(NSString *)aString;

- (NSString *)name;
- (void)setName:(NSString *)aString;

- (NSString *)realname;
- (void)setRealname:(NSString *)aString;

- (NSString *)emailAddress;
- (void)setEmailAddress:(NSString *)aString;

- (NSString *)replyToAddress;
- (void)setReplyToAddress:(NSString *)aString;

- (NSString *)organization;
- (void)setOrganization:(NSString *)aString;

- (NSData *)signature;
- (void)setSignature:(NSData *)aSig;

- (GIAccount *)sendAccount;
- (void)setSendAccount:(GIAccount *)anAccount;

- (NSData *)messageTemplate;
- (void)setMessageTemplate:(NSData *)aTemp;

- (void)addMessageToSend:(GIMessage *)aMessage;
- (void)removeMessageToSend:(GIMessage *)aMessage;


@end
