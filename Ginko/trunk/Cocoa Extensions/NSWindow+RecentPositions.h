//
//  NSWindow+RecentPositions.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 08.05.06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <AppKit/AppKit.h>

@interface NSWindow (OPRecentPositions)

+ (int) unusedWindowSerialOfKind: (NSString*) kind;
- (void) autoPositionWithKind: (NSString*) kind;

@end
