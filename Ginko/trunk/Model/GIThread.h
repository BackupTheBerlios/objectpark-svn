//
//  GIThread.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 02.08.05.
//  Copyright 2005 Objectpark Group. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "OPPersistentObject.h"

@class GIMessageGroup;
@class GIMessage;

@interface GIThread : OPPersistentObject {
	@public // for testing only
}

+ (GIThread*) threadForMessage:(GIMessage*)aMessage;
+ (void) addMessageToAppropriateThread:(GIMessage*)message;

//+ (id) threadInManagedObjectContext: (OPPersistentObjectContext*) aContext;

- (void) calculateDate;
- (NSArray*) messages;
- (void) addMessage:(GIMessage*)aMessage;
- (void) addMessages:(NSArray*)someMessages;

//- (void) addToMessages: (GIMessage*) message;
//- (void) removeFromMessages: (GIMessage*) aMessage;

//- (NSArray*) messagesByDate;
- (NSArray*) messagesByTree;


/*" Groups handling "*/
//- (void) addToGroups: (GIMessageGroup*) group;
//- (void) removeFromGroups: (GIMessageGroup*) group;
//- (void) removeAllFromGroups;

- (unsigned) messageCount;
- (NSArray*) rootMessages;
- (unsigned) commentDepth;
- (BOOL) hasUnreadMessages;
- (BOOL) containsSingleMessage;

- (void) addToGroups_Manually: (GIMessageGroup*) newGroup;

- (void) mergeMessagesFromThread: (GIThread*) anotherThread;

@end

extern NSString *GIThreadDidChangeNotification;