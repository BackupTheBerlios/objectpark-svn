//
//  GIPOPJob.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 09.06.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <AppKit/AppKit.h>

@class G3Account;

@interface GIPOPJob : NSObject 
{
    G3Account *account;
}

+ (void) retrieveMessagesFromPOPAccount:(G3Account *)anAccount;
+ (NSString*) jobName;

@end
