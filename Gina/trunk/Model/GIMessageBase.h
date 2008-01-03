//
//  GIMessageBase.h
//  Gina
//
//  Created by Dirk Theisen on 03.01.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "OPPersistence.h"

@class GIMessage;

@interface  OPPersistentObjectContext (GIMessageBase)

- (NSMutableDictionary*) messagesByMessageId;
- (GIMessage*) messageForMessageId: (NSString*) messageId;


@end
