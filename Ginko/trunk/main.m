//
//  main.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on Mon Jul 19 2004.
//  Copyright (c) 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//


#import <AppKit/AppKit.h>
#import <SenTestingKit/SenTestProbe.h>
#import "TestNSString+Extensions.h"

int main(int argc, const char *argv[])
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    // Make Ginko use the private sqlite dylib from application bundle
    // instead of the one installed in /usr/lib:
    //setenv("LD_LIBRARY_PATH", [[[NSBundle mainBundle] privateFrameworksPath] cString], 1);
    
	//[TestNSStringExtensions testHTMLStrip];
	
    [pool release];
    // Hack to enable desktop launching:
	if (argc>1 && [[[NSString alloc] initWithCString: argv[1]] hasPrefix: @"-psn"])
        argc = 1;
	
	return argc>1 ? SenSelfTestMain() : NSApplicationMain(argc, argv);
}
