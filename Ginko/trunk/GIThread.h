//
//  GIThread.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 02.08.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OPPersistentObject.h"

@class GIMessageGroup;
@class GIMessage;

@interface GIThread : OPPersistentObject {

}

+ (id) threadInManagedObjectContext:(NSManagedObjectContext *)aContext;
+ (NSString*) URIStringPrefix;

- (NSSet*) messages;
- (void)addMessage:(GIMessage *)message;
- (void)removeMessage:(GIMessage *)aMessage;

- (NSArray*) messagesByDate;
- (NSArray*) messagesByTree;


	/*" Groups handling "*/
- (void)addGroup:(GIMessageGroup *)aGroup;
- (void)addGroups:(NSSet *)someGroups;
- (void)removeGroup:(GIMessageGroup *)aGroup; 
- (void)removeFromAllGroups;

- (unsigned)messageCount;
- (NSArray *)rootMessages;
- (unsigned)commentDepth;
- (BOOL)hasUnreadMessages;

- (GIThread *)IplitWithMessage:(GIMessage *)aMessage;
- (void)mergeMessagesFromThread:(GIThread *)anotherThread;


@end
