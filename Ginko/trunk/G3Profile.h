//
//  G3Profile.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 16.12.04.
//  Copyright 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OPManagedObject.h"

@class OPInternetMessage;
@class G3Account;

@interface G3Profile : OPManagedObject 
{
}

+ (NSArray *)profiles;
+ (void)setProfiles:(NSArray *)someProfiles;
+ (G3Profile *)defaultProfile;
+ (G3Profile *)guessedProfileForReplyingToMessage:(OPInternetMessage *)aMessage;

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

- (G3Account *)sendAccount;
- (void)setSendAccount:(G3Account *)anAccount;

- (NSData *)messageTemplate;
- (void)setMessageTemplate:(NSData *)aTemp;

@end
