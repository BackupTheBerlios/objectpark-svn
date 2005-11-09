//
//  NSEnumerator+Extensions.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 26.10.05.
//  Copyright 2005 Dirk Theisen. All rights reserved.
//

#import "NSEnumerator+Extensions.h"


@implementation NSEnumerator (OPExtensions)

- (void) makeObjectsPerformSelector: (SEL) selector
/*" Performs the given selector on all remaining objects. Afterward that, -nextObject returns nil. "*/
{
	id object;
	while (object = [self nextObject]) {
		[object performSelector: selector];
	}
}

- (void) makeObjectsPerformSelector: (SEL) selector withObject: (id) object
	/*" Performs the given selector on all remaining objects with the given parameter object. Afterward that, -nextObject returns nil. "*/
{
	id element;
	while (element = [self nextObject]) {
		[element performSelector: selector withObject: object];
	}
}


@end
