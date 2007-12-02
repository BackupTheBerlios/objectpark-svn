//
//  NSApplication+AppSupportDirectory.m
//  Ginko
//
//  Created by Axel Katerbau on Sun Apr 06 2003.
//  Copyright (c) 2003 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "NSApplication+OPExtensions.h"

@implementation NSApplication (AppSupportDirectory)

- (NSString*) applicationSupportPath
/*" Ensures that the receivers Application Support folder is in place and returns the path. "*/
{
    static NSString *path = nil;

    if (! path) 
    {
        NSString *identifier = [[[NSBundle mainBundle] bundleIdentifier] pathExtension];
        //processName = [[NSProcessInfo processInfo] processName];
        path = [[[[NSHomeDirectory() stringByAppendingPathComponent: @"Library"] stringByAppendingPathComponent:@"Application Support"] stringByAppendingPathComponent:identifier] retain];

        if (! [[NSFileManager defaultManager] fileExistsAtPath:path]) 
        {
            if (! [[NSFileManager defaultManager] createDirectoryAtPath:path attributes: nil]) 
            {
                [NSException raise:NSGenericException format: @"Ginko's Application Support folder could not be created!"];
            }
        }
    }

    return path;
}

@end
