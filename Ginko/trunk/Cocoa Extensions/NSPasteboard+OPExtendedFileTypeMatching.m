/*
 $Id: NSPasteboard+OPExtendedFileTypeMatching.m,v 1.3 2003/03/17 17:12:34 mikesch Exp $

 Copyright (c) 2002 by Dirk Theisen. All rights reserved.

 Permission to use, copy, modify and distribute this software and its documentation
 is hereby granted, provided that both the copyright notice and this permission
 notice appear in all copies of the software, derivative works or modified versions,
 and any portions thereof, and that both notices appear in supporting documentation,
 and that credit is given to Dirk Theisen in all documents and publicity
 pertaining to direct or indirect use of this code or its derivatives.

 THIS IS EXPERIMENTAL SOFTWARE AND IT IS KNOWN TO HAVE BUGS, SOME OF WHICH MAY HAVE
 SERIOUS CONSEQUENCES. THE COPYRIGHT HOLDER ALLOWS FREE USE OF THIS SOFTWARE IN ITS
 "AS IS" CONDITION. THE COPYRIGHT HOLDER DISCLAIMS ANY LIABILITY OF ANY KIND FOR ANY
 DAMAGES WHATSOEVER RESULTING DIRECTLY OR INDIRECTLY FROM THE USE OF THIS SOFTWARE
 OR OF ANY DERIVATIVE WORK.

 Further information can be found on the project's web pages
 at http://www.objectpark.org/Ginko.html
 */

#import "NSPasteboard+OPExtendedFileTypeMatching.h"

@implementation NSPasteboard (OPExtendedFileTypeMatching)

- (NSArray *)filenamesOfType:(NSString *)extension
/*" Returns an array of file names with the extension specified, nil none of those are on the pasteboard."*/
{
    NSMutableArray *results   = nil; // created lazily, if any
    NSString *filename  = nil;
    id filenames = [self propertyListForType:NSFilenamesPboardType];
    
    if ([filenames isKindOfClass:[NSArray class]]) // NO, if filenames==nil
    {
        NSEnumerator *e = [filenames objectEnumerator];
        // Iterate over all file names and declare all NSTypedFilenamesPboardTypes:
        while (filename = [e nextObject]) {
            NSString *thisExtension = [filename pathExtension];
            if ([thisExtension isEqualToString:extension]) {
                if (!results) results = [NSMutableArray array];
                [results addObject:filename];
            }
        }
    } 
    else if ([filenames isKindOfClass:[NSString class]])
    {
        results = [NSArray arrayWithObject:filenames];
    }
    
    return results;
}

@end
