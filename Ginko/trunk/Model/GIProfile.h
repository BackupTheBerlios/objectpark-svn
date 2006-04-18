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

@interface GIProfile : OPPersistentObject {
}

/*" Accessing profiles "*/
+ (NSArray *)allObjects;
+ (GIProfile *)guessedProfileForReplyingToMessage:(OPInternetMessage *)aMessage;

/*" Utility methods "*/
+ (BOOL)isMyEmailAddress:(NSString *)aString;

/*" Default Profile "*/
+ (GIProfile *)defaultProfile;
+ (void)setDefaultProfile:(GIProfile *)aProfile;
- (BOOL)isDefaultProfile;
- (void)makeDefaultProfile;

@end
