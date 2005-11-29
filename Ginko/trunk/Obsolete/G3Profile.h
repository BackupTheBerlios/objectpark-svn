//
//  G3Profile.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 16.12.04.
//  Copyright 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "OPManagedObject.h"

@class OPInternetMessage;
@class GIAccount;
@class G3Message;

@interface G3Profile : NSManagedObject 
{
}

+ (NSArray*) allObjects;
+ (void) setProfiles:(NSArray*) someProfiles;
+ (G3Profile *)defaultProfile;
+ (G3Profile *)guessedProfileForReplyingToMessage: (OPInternetMessage*) aMessage;

+ (BOOL)isMyEmailAddress: (NSString*) aString;

/*
- (NSString*) name;
- (void) setName: (NSString*) aString;

- (NSString*) realname;
- (void) setRealname: (NSString*) aString;

- (void) setEmailAddress: (NSString*) aString;

- (NSString*) replyToAddress;
- (void) setReplyToAddress: (NSString*) aString;

- (NSString*) organization;
- (void) setOrganization: (NSString*) aString;

- (NSData*) signature;
- (void) setSignature: (NSData*) aSig;
*/

- (NSString*) emailAddress;

- (void) addMessageToSend: (G3Message*) aMessage;
- (void) removeMessageToSend: (G3Message*) aMessage;

- (void) removeValue: (id) value forKey: (NSString*) key; // for forward compatibility only

@end
