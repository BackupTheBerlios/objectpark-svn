//
//  GISMTPJob.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 13.06.05.
//  Copyright 2005 Objectpark Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class G3Account;

@interface GISMTPJob : NSObject 
{
    NSArray *messages;
    G3Account *account;
}

+ (void)sendMessages:(NSArray *)someMessages viaSMTPAccount:(G3Account *)anAccount;
+ (NSString *)jobName;

@end
