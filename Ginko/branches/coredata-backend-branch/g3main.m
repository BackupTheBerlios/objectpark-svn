//
//  main.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on Mon Jul 19 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//


#import <Cocoa/Cocoa.h>
#import "G3Message.h"
#import "OPMBoxFile.h"
#import "G3Thread.h"
#import "OPInternetMessage.h"

char*  op_debug_setting;
char** op_debug_domain;

void enumerateMboxTest() 
{


}


int main(int argc, const char *argv[])
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	//enumerateMboxTest();
    return NSApplicationMain(argc, argv);
	
	[pool release];
	return 0;
}
