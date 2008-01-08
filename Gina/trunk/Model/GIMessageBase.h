//
//  GIMessageBase.h
//  Gina
//
//  Created by Dirk Theisen on 03.01.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "OPPersistence.h"

@class GIMessage;
@class GIMessageGroup;

@interface  OPPersistentObjectContext (GIMessageBase)

- (void)addMessage: (GIMessage*) aMessage;
- (NSMutableDictionary*) messagesByMessageId;
- (GIMessage*) messageForMessageId: (NSString*) messageId;
- (void) importMboxFiles: (NSArray*) paths
		   moveOnSuccess: (BOOL) doMove;

- (void) moveThreadsWithOids: (NSArray*) threadOids 
				   fromGroup: (GIMessageGroup*) sourceGroup 
					 toGroup: (GIMessageGroup*) destinationGroup;

@end
