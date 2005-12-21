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

+ (GIFulltextIndexCenter *)sharedFulltextIndex;
- (NSString *)fulltextIndexPath;

- (LuceneDocument *)luceneDocumentFromMessage:(id)aMessage;
- (BOOL)addMessages:(NSArray *)someMessages;

@end

