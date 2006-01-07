//
//  GIMessageBase.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 06.04.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <AppKit/AppKit.h>
@class OPMBoxFile;
@class GIMessage;
@class GIMessageGroup;
@class GIThread;

@interface GIMessageBase : NSObject 
{
}

+ (void)addMessage:(GIMessage *)aMessage;

+ (NSSet *)defaultGroupsForMessage:(GIMessage *)aMessage;

- (void)importMessagesFromMboxFileJob:(NSMutableDictionary *)arguments;

+ (void)addMessage:(GIMessage *)aMessage toMessageGroup:(GIMessageGroup *)aGroup suppressThreading:(BOOL)suppressThreading;
+ (void)addDraftMessage: (GIMessage *)aMessage;
+ (void)addQueuedMessage: (GIMessage *)aMessage;
+ (void)addTrashThread:(GIThread *)aThread;

@end

extern NSString *MboxImportJobName;