//
//  NSFileManager+Extensions.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 15.09.06.
//  Copyright 2006 Objectpark Group. All rights reserved.
//

#import "NSFileManager+Extensions.h"

@implementation NSFileManager (OPExtensions)


- (NSArray*) directoryContentsAtPath: (NSString*) path
					   absolutePaths: (BOOL) absolute
{
	NSArray* relativePaths = [self directoryContentsAtPath: path];
	if (!absolute || [relativePaths count] == 0) return relativePaths;
	
	
	NSMutableArray* result = [NSMutableArray arrayWithCapacity: [relativePaths count]];
	NSEnumerator* e = [relativePaths objectEnumerator];
	NSString* relativePath;
	while (relativePath = [e nextObject]) {
		[result addObject: [path stringByAppendingPathComponent: relativePath]];
	}
	return result;
}

@end
