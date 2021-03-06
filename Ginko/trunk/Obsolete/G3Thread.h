//
//  G3Thread.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 02.12.04.
//  Copyright 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "OPManagedObject.h"

@class G3Message;
@class G3MessageGroup;

@interface G3Thread : NSManagedObject 
{
}

+ (G3Thread *)threadInManagedObjectContext: (NSManagedObjectContext*) aContext;
+ (NSString*) URIStringPrefix;

- (BOOL)containsSingleMessage;
- (NSSet *)messages;
- (void) addMessage: (G3Message*) message;
- (void) removeMessage: (G3Message*) aMessage;

- (NSArray*) messagesByDate;
- (NSArray*) messagesByTree;


/*" Groups handling "*/
- (void) addGroup: (G3MessageGroup*) aGroup;
- (void) addGroups: (NSSet*) someGroups;
- (void) removeGroup: (G3MessageGroup*) aGroup; 
- (void) removeFromAllGroups;

- (unsigned)messageCount;
- (NSArray*) rootMessages;
- (unsigned)commentDepth;
- (BOOL)hasUnreadMessages;

- (G3Thread *)splitWithMessage: (G3Message*) aMessage;
- (void) mergeMessagesFromThread: (G3Thread*) anotherThread;

@end
