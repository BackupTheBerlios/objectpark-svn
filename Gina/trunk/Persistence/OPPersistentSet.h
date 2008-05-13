//
//  OPPersistentSet.h
//  Gina
//
//  Created by Dirk Theisen on 09.05.08.
//  Copyright 2008 Objectpark Software GbR. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OPPersistenceConstants.h"


typedef struct OPHashEntry {
	NSUInteger hash;
	OID oid;
} OPHashEntry;

@interface OPPersistentSet : NSMutableSet {
	NSUInteger     count; // number of elements stored
	NSUInteger     entryCount; // number of bOPHashentries allocated. Always > count
	NSUInteger     usedEntryCount;
	OPHashEntry*   entries;
}

@end
