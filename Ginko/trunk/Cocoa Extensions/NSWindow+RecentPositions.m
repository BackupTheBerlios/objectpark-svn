//
//  NSWindow+RecentPositions.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 08.05.06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//
#import "NSWindow+RecentPositions.h"
#import <Foundation/NSDebug.h>

@implementation NSWindow (OPRecentPositions)

+ (int) unusedWindowSerialOfKind: (NSString*) kind
{
	NSMutableIndexSet* usedIndexes = [[NSMutableIndexSet alloc] init];
	
	NSWindow* window;
	NSEnumerator* e = [[NSApp windows] objectEnumerator];
	while (window = [e nextObject]) {
		NSString* autosaveName = [window frameAutosaveName];
		if ([autosaveName hasPrefix: kind]) {
			int index = [[autosaveName substringFromIndex: [kind length]] intValue];
			[usedIndexes addIndex: index];
		}
	}
	// Find first unused Index
	int result = 1;
	while ([usedIndexes containsIndex: result]) result++;
	[usedIndexes release];
	
	return result;
}

- (void) autoPositionWithKind: (NSString*) kind
{
	int serial = [[self class] unusedWindowSerialOfKind: kind];
	NSString* autoSaveName = [NSString stringWithFormat: @"%@%d", kind, serial];
	if (NSDebugEnabled) NSLog(@"Using window autosave name %@", autoSaveName);
	[self setFrameAutosaveName: autoSaveName];
}


@end
