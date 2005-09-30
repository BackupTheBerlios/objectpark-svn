//
//  GIFulltextIndexCenter.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 18.04.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <AppKit/AppKit.h>

@class GIMessage;

@interface GIFulltextIndexCenter : NSObject 
{
}

+ (GIFulltextIndexCenter *)defaultIndexCenter;
- (id)init;

- (BOOL)addMessage:(GIMessage *)aMessage;
- (BOOL)removeMessage:(GIMessage *)aMessage;
- (NSArray *)hitsForQueryString:(NSString *)aQuery;
- (BOOL)reindexAllMessages;

- (NSDictionary *)indexDictionary;
- (void)setIndexDictionary:(NSDictionary *)newIndexDictionary;


@end
