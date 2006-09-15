//
//  GIPOPJob.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 09.06.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <AppKit/AppKit.h>

@class GIAccount;

@interface GIPOPJob : NSObject 
{
    GIAccount *account;
	int authenticationErrorDialogResult;
}

+ (void)retrieveMessagesFromPOPAccount:(GIAccount *)anAccount;
+ (NSString *)jobName;
+ (NSString*) mboxesToImportDirectory;


@end
