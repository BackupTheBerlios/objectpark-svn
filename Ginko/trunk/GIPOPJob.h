//
//  GIPOPJob.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 09.06.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <AppKit/AppKit.h>

@class G3Account;

@interface GIPOPJob : NSObject 
{
    G3Account *account;
}

+ (void)retrieveMessagesFromPOPAccount:(G3Account *)anAccount;
+ (NSString *)jobName;

@end
