//
//  OPPersistentSet.h
//  Gina
//
//  Created by Dirk Theisen on 09.05.08.
//  Copyright 2008 Objectpark Software GbR. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OPPersistenceConstants.h"


typedef struct OPHashBucket {
	NSUInteger hash;
	OID oid;
} OPHashBucket;

@interface OPPersistentSet : NSMutableSet {
	NSUInteger     count; // number of elements stored
	NSUInteger     entryCount; // number of bOPHashentries allocated. Always > count
	NSUInteger     usedentryCount;
	OPHashBucket** entries;
}

@end
