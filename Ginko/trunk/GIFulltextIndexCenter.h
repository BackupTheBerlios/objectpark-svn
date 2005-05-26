//
//  GIFulltextIndexCenter.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 18.04.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class G3Message;

@interface GIFulltextIndexCenter : NSObject 
{
}

+ (id)defaultIndexCenter;

- (BOOL)addMessage:(G3Message *)aMessage;
- (BOOL)removeMessage:(G3Message *)aMessage;
- (NSArray *)hitsForQueryString:(NSString *)aQuery;
- (BOOL)reindexAllMessages;

@end
