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


@interface G3Thread : OPManagedObject {
   // NSMutableDictionary* verticalOffsets;
}

+ (G3Thread*) thread;

- (BOOL) containsSingleMessage;
- (NSSet*) messages;
- (void) addMessage: (G3Message*) message;
- (NSArray*) messagesByDate;


- (unsigned) messageCount;
- (NSArray*) rootMessages;
- (unsigned) commentDepth;
- (BOOL) hasUnreadMessages;

@end
