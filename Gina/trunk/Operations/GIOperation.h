//
//  GIOperation.h
//  Gina
//
//  Created by Axel Katerbau on 16.03.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface GIOperation : NSOperation 
{
	NSDictionary *progressInfo;
	id result;
}

@property (readwrite, copy) NSDictionary *progressInfo;
@property (readwrite, retain) id result;

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

@end
