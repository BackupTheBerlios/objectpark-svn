//
//  $Id:NSThread+OPThreadNames.m$
//  OPDebug
//
//  Created by Jörg Westheide on 24.11.2005.
//  Copyright 2005 Objectpark.org. All rights reserved.
//

#import "NSThread+OPThreadNames.h"

#define OPThreadName  @"OPThreadName"


#define THREAD_ID  (((unsigned int*) self)[1])


@implementation NSThread (OPThreadNames)
/*"This category lets threads have names.
   It therefore provides accesors to the name."*/

/*"Sets the the thread's name to aName.
   If aName is nil a previously set name is removed so the default name is
   used again."*/
- (void) setName:(NSString*) aName
    {
    if (aName)
        [[self threadDictionary] setObject:aName forKey:OPThreadName];
    else
        [[self threadDictionary] removeObjectForKey:OPThreadName];
    }
    
    
/*"Returns the thread's name.
   If no name was set it returns the thread's default name which is
   !{@"MAIN"} for the main thread and
   the decimal representation of the thread's number otherwise."*/
- (NSString*) name
    {
    NSString* name = [[self threadDictionary] objectForKey:OPThreadName];
    
    if (name)
        return name;
        
    if (THREAD_ID == 1)
        return @"MAIN";
        
    return [NSString stringWithFormat:@"%d", THREAD_ID];
    }

@end
