//
//  GIProfile.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 26.07.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "OPPersistentObject.h"



@class OPInternetMessage;
@class GIAccount;
@class GIMessage;

@interface GIProfile : OPPersistentObject {
	
}

+ (NSArray*) allObjects;
+ (GIProfile*) defaultProfile;

+ (GIProfile*) guessedProfileForReplyingToMessage: (OPInternetMessage*) aMessage;

+ (BOOL) isMyEmailAddress: (NSString*) aString;

/*
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
*/

- (NSString*) emailAddress;


@end
