//
//  OPPersistentStringDictionary.m
//  PersistenceKit-Test
//
//  Created by Dirk Theisen on 18.12.07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "OPPersistentStringDictionary.h"


@implementation OPPersistentStringDictionary

- (NSUInteger) count
/*" Can be slow, initial invocation does a table scan. "*/
{
	if (count == NSNotFound) {
		// do count the items
		count = [btree entryCount]; // may be expensive
	}
	return count;
}

@end
