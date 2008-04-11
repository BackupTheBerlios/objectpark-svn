//
//  GIThread.h
//  Gina
//
//  Created by Dirk Theisen on 02.08.05.
//  Copyright 2005 Objectpark Group. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "OPPersistentObject.h"

@class GIMessageGroup;
@class GIMessage;
@class OPFaultingArray;

@interface GIThread : OPPersistentObject {
@private
	NSString* subject;  // persistent
	NSDate* date;       // persistent
	OPFaultingArray* messages;           // persistent
	OPFaultingArray* messageGroups;      // persistent
	OPFaultingArray* messagesByTree;     // transient cache - needed?
	int unreadMessageCount;
}

@property (copy) NSString* subject;  // persistent
@property (retain) NSDate* date;     // persistent
@property (readonly) int unreadMessageCount; // persistent
@property (readonly) BOOL isSeen; // calculated from unreadMessageCount

+ (GIThread*) threadForMessage:(GIMessage*)aMessage;
+ (void) addMessageToAppropriateThread:(GIMessage*)message;

- (void) calculateDate;
- (NSArray*) messages;
- (NSArray*) messageGroups;

- (NSArray*) messagesByTree; // slow!!

- (GIMessage*) nextMessageForMessage: (GIMessage*) previousMessage;


/*" Used in inverse relationship handling. "*/
- (void) insertPrimitiveObject: (GIMessageGroup*) group inMessageGroupsAtIndex: (NSUInteger) index;
- (void) removePrimitiveObjectFromMessageGroupsAtIndex: (NSUInteger) index;

/*" Groups handling "*/

- (NSUInteger)messageCount;
- (NSArray*) rootMessages;
- (NSUInteger)commentDepth;
- (BOOL) containsSingleMessage;

//- (void) addToGroups_Manually: (GIMessageGroup*) newGroup;

- (void) mergeMessagesFromThread: (GIThread*) anotherThread;

- (void) didToggleFlags: (unsigned) flag ofContainedMessage: (GIMessage*) message;


@end

extern NSString *GIThreadDidChangeNotification;