//
//  NSEnumerator+Extensions.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 26.10.05.
//  Copyright 2005 Dirk Theisen. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSEnumerator (OPExtensions)

- (void) makeObjectsPerformSelector: (SEL) selector;
- (void) makeObjectsPerformSelector: (SEL) selector withObject: (id) object;
- (void) makeObjectsPerformSelector: (SEL) selector withObject: (id) object1 withObject: (id) object2;

@end
