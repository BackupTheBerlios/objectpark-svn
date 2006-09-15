//
//  NSFileManager+Extensions.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 15.09.06.
//  Copyright 2006 Objectpark Group. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSFileManager (OPExtensions)

- (NSArray*) directoryContentsAtPath: (NSString*) path
					   absolutePaths: (BOOL) absolute;

@end
