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
@class GIMessageGroup;
@class OPFaultingArray;

@interface GIFulltextIndex : NSObject 
{
}

+ (NSString *)fulltextIndexPath;

+ (void)addMessages:(OPFaultingArray *)someMessages;
+ (void)fulltextIndexInBackgroundAdding:(OPFaultingArray *)messagesToAdd removing:(OPFaultingArray *)messagesToRemove;
+ (void)removeMessages:(OPFaultingArray *)someMessages;

+ (NSArray *)hitsForQueryString:(NSString *)aQuery defaultField:(NSString *)defaultField group:(GIMessageGroup *)aGroup limit:(int)limit;

+ (void)optimize;
+ (void)resetIndex;

+ (NSString *)jobName;

@end
