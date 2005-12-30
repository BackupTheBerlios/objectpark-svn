//
//  GIFulltextIndexJob.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 28.12.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "GIFulltextIndexJob.h"
#import "OPJobs.h"
#import "GIFulltextIndexCenter.h"

@implementation GIFulltextIndexJob

- (void)fulltextIndexMessagesJob:(NSDictionary *)arguments
{
    [OPJobs setProgressInfo:[OPJobs indeterminateProgressInfoWithDescription:NSLocalizedString(@"fulltext indexing", @"progress description in fulltext index job")]];
    
    [GIFulltextIndexCenter addMessages:messagesToIndexEnumerator];
}

- (id)initWithMessages:(OPPersistentObjectEnumerator *)someMessages
{
    self = [super init];
    
    messagesToIndexEnumerator = [someMessages retain];
    
    return self;
}

- (void)dealloc
{
    [messagesToIndexEnumerator release];
    [super dealloc];
}

+ (void)indexMessages:(OPPersistentObjectEnumerator *)someMessages
/*" Starts a background job for fulltext indexing someMessages. Only one indexing job can be active at one time. "*/
{
    NSMutableDictionary *jobArguments = [NSMutableDictionary dictionary];
    
    [jobArguments setObject:someMessages forKey:@"messagesToIndexEnumerator"];
    
    [OPJobs scheduleJobWithName:[self jobName] target:[[[self alloc] initWithMessages:someMessages] autorelease] selector:@selector(fulltextIndexMessagesJob:) arguments:jobArguments synchronizedObject:@"fulltextIndexing"];
}

+ (NSString *)jobName
{
    return @"Fulltext indexing";
}

@end
