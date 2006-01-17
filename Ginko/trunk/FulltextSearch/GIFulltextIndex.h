//
//  GIFulltextIndex.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 18.04.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "Lucene.h"
#include <JavaVM/jni.h>

@class GIMessage;

@interface GIFulltextIndex : NSObject 
{
}

+ (NSString *)fulltextIndexPath;

+ (void)addMessages:(NSArray *)someMessages;
+ (void)fulltextIndexInBackgroundAdding:(NSArray *)messagesToAdd removing:(NSArray *)messageOidsToRemove;
+ (void)removeMessagesWithOids:(NSArray *)someOids;

+ (NSArray *)hitsForQueryString:(NSString *)aQuery;

+ (void)optimize;
+ (void)resetIndex;

+ (NSString *)jobName;

@end