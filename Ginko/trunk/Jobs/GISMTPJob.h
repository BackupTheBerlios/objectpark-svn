//
//  GISMTPJob.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 13.06.05.
//  Copyright 2005 Objectpark Group. All rights reserved.
//

#import <AppKit/AppKit.h>

@class GIAccount;

@interface GISMTPJob : NSObject 
{
    NSArray* messages;
    GIAccount* account;
}

+ (void) sendMessages:(NSArray*) someMessages viaSMTPAccount:(GIAccount *)anAccount;
+ (NSString*) jobName;

@end
