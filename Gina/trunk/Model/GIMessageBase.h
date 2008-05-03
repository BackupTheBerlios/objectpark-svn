//
//  GIMessageBase.h
//  Gina
//
//  Created by Dirk Theisen on 03.01.08.
//  Copyright 2008 Objectpark Group. All rights reserved.
//

#import "OPPersistence.h"

@class GIMessage;
@class GIMessageGroup;

@interface  OPPersistentObjectContext (GIMessageBase)

- (void)addMessageByApplingFilters:(GIMessage *)aMessage;
- (NSMutableDictionary *)messagesByMessageId;
- (GIMessage *)messageForMessageId:(NSString *)messageId;

- (NSArray *)importMboxFiles:(NSArray *)paths moveOnSuccess:(BOOL)doMove;
- (NSArray *)importGmlFiles:(NSArray *)gmls moveOnSuccess:(BOOL)move;

- (OID)oidFromMessageFilename:(NSString *)filename;

- (NSString *)transferDataDirectory;
- (NSString *)documentPath;

@end
