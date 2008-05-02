//
//  main.m
//  Gina
//
//  Created by Axel Katerbau on 30.11.07.
//  Copyright Objectpark Group 2007. All rights reserved.
//

#import <Cocoa/Cocoa.h>

int main(int argc, char *argv[])
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	NSArray* arguments = [[NSProcessInfo processInfo] arguments];
	if ([arguments containsObject: @"-SenTest"]) {
		NSLog(@"Test mode active.");
		NSArray* testBundlePaths = [[NSBundle mainBundle] pathsForResourcesOfType: @"octest" inDirectory: nil];
		
		for (NSString* bundlePath in testBundlePaths) {
			NSBundle* testBundle = [NSBundle bundleWithPath: bundlePath];
			NSLog(@"Loading test bundle at '%@'", bundlePath);
			[testBundle load];
		}

		
		id testProbe = NSClassFromString (@"SenTestProbe");
        if (testProbe != nil) {
            [testProbe performSelector: @selector(runTests:) withObject:nil];
        }
	}
	[pool release];
    return NSApplicationMain(argc,  (const char **) argv);
}
