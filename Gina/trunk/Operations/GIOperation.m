//
//  GIOperation.m
//  Gina
//
//  Created by Axel Katerbau on 16.03.08.
//  Copyright 2008 Objectpark Group. All rights reserved.
//

#import "GIOperation.h"

NSString *JobProgressMinValue = @"OPJobProgressMinValue";
NSString *JobProgressMaxValue = @"OPJobProgressMaxValue";
NSString *JobProgressCurrentValue = @"OPJobProgressCurrentValue";
NSString *JobProgressDescription = @"OPJobProgressDescription";

NSString *GIOperationLock = @"GIOperationLock";

@implementation GIOperation

@synthesize progressInfo;

- (void)setProgressInfoWithMinValue:(double)aMinValue maxValue:(double)aMaxValue currentValue:(double)currentValue description:(NSString *)aDescription
{
	@synchronized(GIOperationLock)
	{
		NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
							  [NSNumber numberWithDouble:aMinValue], JobProgressMinValue,
							  [NSNumber numberWithDouble:aMaxValue], JobProgressMaxValue,
							  [NSNumber numberWithDouble:currentValue], JobProgressCurrentValue,
							  aDescription, JobProgressDescription,
							  nil, nil];
		
		[self willChangeValueForKey:@"progessInfo"];
		self.progressInfo = info;
		[self didChangeValueForKey:@"progessInfo"];
	}
}

- (void)setIndeterminateProgressInfoWithDescription:(NSString *)aDescription
{
	@synchronized(GIOperationLock)
	{
		NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
							  aDescription, JobProgressDescription,
							  nil, nil];
		
		[self willChangeValueForKey:@"progessInfo"];
		self.progressInfo = info;
		[self didChangeValueForKey:@"progessInfo"];
	}
}

- (void)dealloc
{
	@synchronized(GIOperationLock)
	{
		[self willChangeValueForKey:@"progessInfo"];
		self.progressInfo = nil;
		[self didChangeValueForKey:@"progessInfo"];

		[progressInfo release];
	}
	
	[super dealloc];
}

@end

#import "GIPasswordController.h"
#import "GIAccount.h"

@implementation GIOperation (GinkoExtensions)

+ (void)openPasswordPanel:(NSMutableDictionary *)someParameters
/*" Called in main thread to open the panel. "*/
{
    [[[GIPasswordController alloc] initWithParamenters:someParameters] autorelease];
}

+ (NSString *)runPasswordPanelWithAccount:(GIAccount *)anAccount forIncomingPassword:(BOOL)isIncoming
{
    NSParameterAssert(anAccount != nil);
	
    NSMutableDictionary *rslt = [NSMutableDictionary dictionary];
    // prepare parameter dictionary for cross thread method call
    NSMutableDictionary *parameterDict = [NSMutableDictionary dictionary];
    [parameterDict setObject:[NSNumber numberWithBool:isIncoming] forKey:@"isIncoming"];
    [parameterDict setObject:anAccount forKey:@"account"];
    [parameterDict setObject:rslt forKey:@"result"];
    
    // open panel in main thread
    [self performSelectorOnMainThread:@selector(openPasswordPanel:) withObject:parameterDict waitUntilDone:YES];
    
    NSString *password = nil;
    
    // wait for the panel controller to set an object for key @"finished".
    do
    {
        id finished;
        
        @synchronized(rslt) 
        {
            finished = [rslt objectForKey:@"finished"];
            password = [rslt objectForKey:@"password"];
        }
		
        if (finished) break;
        
        else
        {
            // sleep for 1 second
            //[[NSRunLoop currentRunLoop] run];
            [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
        }
    }
    while (YES);
    
    return password;
}

+ (void)presentException:(NSException *)exception
{
	NSParameterAssert(exception != nil);
	
	NSString *localizedDescription = [[exception userInfo] objectForKey:NSLocalizedDescriptionKey];
	
	NSError *error = [NSError errorWithDomain:@"GinaDomain" code:0 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:localizedDescription ? localizedDescription : [exception reason], NSLocalizedDescriptionKey, 
																			  nil]];
	[[NSApplication sharedApplication] performSelectorOnMainThread:@selector(presentError:) withObject:error waitUntilDone:NO];
}

@end

