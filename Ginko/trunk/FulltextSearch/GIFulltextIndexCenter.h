//
//  GIFulltextIndexCenter.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 18.04.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "Lucene.h"

@class GIMessage;

@interface GIFulltextIndexCenter : NSObject 
{
}

+ (NSString *)fulltextIndexPath;

+ (BOOL)addMessages:(NSArray *)someMessages;

+ (LuceneHits *)hitsForQueryString:(NSString *)aQueryString;

+ (void)optimize;

@end

