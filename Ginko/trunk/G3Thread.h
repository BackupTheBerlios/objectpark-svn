//
//  G3Thread.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 02.12.04.
//  Copyright 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OPManagedObject.h"

@class G3Message;
@class G3MessageGroup;

@interface G3Thread : OPManagedObject 
{
}

+ (G3Thread*) thread;

- (BOOL) containsSingleMessage;
- (NSSet*) messages;
- (void) addMessage: (G3Message*) message;
- (NSArray*) messagesByDate;

/*" Groups handling "*/
- (void)addGroup:(G3MessageGroup *)aGroup;
- (void)addGroups:(NSSet *)someGroups;
- (void)removeGroup:(G3MessageGroup *)aGroup; 

- (unsigned) messageCount;
- (NSArray*) rootMessages;
- (unsigned) commentDepth;
- (BOOL) hasUnreadMessages;

- (G3Thread *)splitWithMessage:(G3Message *)aMessage;
- (void)mergeMessagesFromThread:(G3Thread *)anotherThread;

@end
