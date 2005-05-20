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

+ (G3Message*) insertMessageWithTransferData: (NSData*) transferData;

+ (void)removeMessage:(G3Message *)aMessage;

+ (NSArray*) defaultGroupsForMessage: (G3Message*) aMessage;

+ (void) importFromMBoxFile: (OPMBoxFile*) box;

+ (void)addMessage:(G3Message *)aMessage toMessageGroup:(G3MessageGroup *)aGroup;
+ (void)addOutgoingMessage:(G3Message *)aMessage;

/*" deprecated methods (moved to G3MessageGroup) "*/
/*
+ (G3MessageGroup *)defaultMessageGroup;
+ (G3MessageGroup *)outgoingMessageGroup;
+ (G3MessageGroup *)draftMessageGroup;
+ (G3MessageGroup *)spamMessageGroup;
*/
@end
