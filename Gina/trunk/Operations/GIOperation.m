//
//  GIOperation.m
//  Gina
//
//  Created by Axel Katerbau on 16.03.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "GIOperation.h"

NSString *JobProgressMinValue = @"OPJobProgressMinValue";
NSString *JobProgressMaxValue = @"OPJobProgressMaxValue";
NSString *JobProgressCurrentValue = @"OPJobProgressCurrentValue";
NSString *JobProgressDescription = @"OPJobProgressDescription";

@implementation GIOperation

@synthesize progressInfo;
@synthesize result;

- (void)setProgressInfoWithMinValue:(double)aMinValue maxValue:(double)aMaxValue currentValue:(double)currentValue description:(NSString *)aDescription
{
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithDouble:aMinValue], JobProgressMinValue,
			[NSNumber numberWithDouble:aMaxValue], JobProgressMaxValue,
			[NSNumber numberWithDouble:currentValue], JobProgressCurrentValue,
			aDescription, JobProgressDescription,
			nil, nil];
	
	self.progressInfo = info;
}

- (void)setIndeterminateProgressInfoWithDescription:(NSString *)aDescription
{
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
			aDescription, JobProgressDescription,
			nil, nil];
	
	self.progressInfo = info;
}

- (void)dealloc
{
	[progressInfo release];
	[result release];
	
	[super dealloc];
}

@end

