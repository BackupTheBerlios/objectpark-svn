//
//  GIPOPOperation.h
//  Gina
//
//  Created by Axel Katerbau on 16.03.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GIOperation.h"

@class GIAccount;

@interface GIPOPOperation : GIOperation 
{
	GIAccount *account;
	int authenticationErrorDialogResult;
}

@property (readonly, retain) GIAccount *account;

+ (void)retrieveMessagesFromPOPAccount:(GIAccount *)anAccount usingOperationQueue:(NSOperationQueue *)queue;

- (id)initWithAccount:(GIAccount *)anAccount;

@end

extern NSString *GIPOPOperationDidStartNotification;
extern NSString *GIPOPOperationDidEndNotification;
