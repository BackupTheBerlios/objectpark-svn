//
//  GIMessageBase.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 06.04.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <AppKit/AppKit.h>
@class OPMBoxFile;
@class G3Message;
@class G3MessageGroup;
@class G3Thread;

@interface GIMessageBase : NSObject {

}

+ (G3Message *)addMessageWithTransferData:(NSData *)someTransferData;

+ (void)removeMessage:(G3Message *)aMessage;

+ (NSSet *)defaultGroupsForMessage:(G3Message *)aMessage;

- (void)importMessagesFromMboxFileJob:(NSMutableDictionary *)arguments;

+ (void)addMessage:(G3Message *)aMessage toMessageGroup:(G3MessageGroup *)aGroup suppressThreading:(BOOL)suppressThreading;
+ (void)addSentMessage:(G3Message *)aMessage;
+ (void)addDraftMessage:(G3Message *)aMessage;
+ (void)addQueuedMessage:(G3Message *)aMessage;
+ (void)addTrashThread:(G3Thread *)aThread;
+ (void)removeDraftMessage:(G3Message *)aMessage;

@end

extern NSString *MboxImportJobName;