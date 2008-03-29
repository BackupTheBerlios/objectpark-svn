//
//  GISMTPOperation.h
//  Gina
//
//  Created by Axel Katerbau on 28.03.08.
//  Copyright 2008 Objectpark Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GIOperation.h"

@class GIAccount;

@interface GISMTPOperation : GIOperation 
{
    GIAccount *account;
    NSArray *messages;
	int authenticationErrorDialogResult;
}

@property (readonly, retain) GIAccount *account;
@property (readonly, retain) NSArray *messages;

+ (void)sendMessages:(NSArray *)someMessages viaSMTPAccount:(GIAccount *)anAccount usingOperationQueue:(NSOperationQueue *)queue;

- (id)initWithMessages:(NSArray *)someMessages andAccount:(GIAccount *)anAccount;

@end

extern NSString *GISMTPOperationDidEndNotification;