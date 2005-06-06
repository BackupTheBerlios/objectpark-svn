//
//  GIMessageBase.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 06.04.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class OPMBoxFile;
@class G3Message;
@class G3MessageGroup;

@interface GIMessageBase : NSObject {

}

+ (G3Message *)addMessageWithTransferData:(NSData *)someTransferData;

+ (void)removeMessage:(G3Message *)aMessage;

+ (NSSet *)defaultGroupsForMessage:(G3Message *)aMessage;

- (void)importMessagesFromMboxFileJob:(NSMutableDictionary *)arguments;

+ (void)addMessage:(G3Message *)aMessage toMessageGroup:(G3MessageGroup *)aGroup;
+ (void)addOutgoingMessage:(G3Message *)aMessage;

@end
