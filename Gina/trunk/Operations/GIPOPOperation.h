//
//  GIPOPOperation.h
//  Gina
//
//  Created by Axel Katerbau on 16.03.08.
//  Copyright 2008 Objectpark Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GIOperation.h"

@class GIAccount;

@interface GIPOPOperation : GIOperation 
{
	GIAccount *account;
	NSString *transferDataPath;
	int authenticationErrorDialogResult;
}

@property (readonly, retain) GIAccount *account;

+ (void)retrieveMessagesFromPOPAccount:(GIAccount *)anAccount usingOperationQueue:(NSOperationQueue *)queue putIntoDirectory:(NSString *)path;

- (id)initWithAccount:(GIAccount *)anAccount transferDataPath:(NSString *)dataPath;

@end

extern NSString *GIPOPOperationDidStartNotification;
extern NSString *GIPOPOperationDidEndNotification;
