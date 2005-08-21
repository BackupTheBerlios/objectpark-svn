//
//  GIThread.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 02.08.05.
//  Copyright 2005 Objectpark Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OPPersistentObject.h"

@class GIMessageGroup;
@class GIMessage;

@interface GIThread : OPPersistentObject {
	@public // for testing only
	int age; // since reference date (should be 1970)
}

//+ (id) threadInManagedObjectContext:(NSManagedObjectContext *)aContext;

- (NSSet*) messages;
- (void) addMessage:(GIMessage *)message;
- (void) removeMessage:(GIMessage *)aMessage;

//- (NSArray*) messagesByDate;
- (NSArray*) messagesByTree;


/*" Groups handling "*/
- (void) addToGroups: (GIMessageGroup*) group;
- (void) removeFromGroups: (GIMessageGroup*) group;
- (void) removeAllFromGroups;

- (unsigned) messageCount;
- (NSArray*) rootMessages;
- (unsigned) commentDepth;
- (BOOL) hasUnreadMessages;

- (GIThread*) splitWithMessage: (GIMessage*) aMessage;
- (void) mergeMessagesFromThread: (GIThread*) anotherThread;


@end
