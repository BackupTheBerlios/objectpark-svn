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
}

@property (copy) NSString* subject;  // persistent
@property (retain) NSDate* date;     // persistent

+ (GIThread*) threadForMessage:(GIMessage*)aMessage;
+ (void) addMessageToAppropriateThread:(GIMessage*)message;

- (void) calculateDate;
- (NSArray*) messages;
- (NSArray*) messageGroups;

- (OPFaultingArray*) messagesByTree;


/*" Groups handling "*/

- (NSUInteger)messageCount;
- (NSArray*) rootMessages;
- (NSUInteger)commentDepth;
- (BOOL) isSeen;
- (BOOL) containsSingleMessage;

//- (void) addToGroups_Manually: (GIMessageGroup*) newGroup;

- (void) mergeMessagesFromThread: (GIThread*) anotherThread;

@end

extern NSString *GIThreadDidChangeNotification;