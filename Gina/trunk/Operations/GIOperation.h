//
//  GIOperation.h
//  Gina
//
//  Created by Axel Katerbau on 16.03.08.
//  Copyright 2008 Objectpark Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface GIOperation : NSOperation 
{
	NSDictionary *progressInfo;
}

@property (readwrite, copy) NSDictionary *progressInfo;

- (void)setProgressInfoWithMinValue:(double)aMinValue maxValue:(double)aMaxValue currentValue:(double)currentValue description:(NSString *)aDescription;
- (void)setIndeterminateProgressInfoWithDescription:(NSString *)aDescription;

@end

extern NSString *JobProgressMinValue;
extern NSString *JobProgressMaxValue;
extern NSString *JobProgressCurrentValue;
extern NSString *JobProgressDescription;

@class GIAccount;

@interface GIOperation (GinkoExtensions)

+ (NSString *)runPasswordPanelWithAccount:(GIAccount *)anAccount forIncomingPassword:(BOOL)isIncoming;
+ (void)presentException:(NSException *)exception;

@end
