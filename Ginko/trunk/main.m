//
//  main.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on Mon Jul 19 2004.
//  Copyright (c) 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//


#import <AppKit/AppKit.h>
#import "G3Message.h"
#import "G3Thread.h"
//#include <stdlib.h>

 char*  op_debug_setting;
 char** op_debug_domain;

int main(int argc, const char *argv[])
{
    //NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    // Make Ginko use the private sqlite dylib from application bundle
    // instead of the one installed in /usr/lib:
    //setenv("LD_LIBRARY_PATH", [[[NSBundle mainBundle] privateFrameworksPath] cString], 1);
    //[pool release];
    return NSApplicationMain(argc, argv);
}
