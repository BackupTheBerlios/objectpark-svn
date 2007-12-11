//
//  GIApplication.m
//  Gina
//
//  Created by Axel Katerbau on 10.12.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import "GIApplication.h"
#import "GIUserDefaultsKeys.h"

@implementation GIApplication

- (BOOL)isDefaultMailApplication
{
	NSString *defaultMailAppBundleIdentifier = (NSString *)LSCopyDefaultHandlerForURLScheme((CFStringRef)@"mailto");
	NSString *bundleIdentifier = [[[NSBundle mainBundle] bundleIdentifier] lowercaseString];
	[defaultMailAppBundleIdentifier autorelease];
	
	return [bundleIdentifier isEqualToString:defaultMailAppBundleIdentifier];
}

- (void)askForBecomingDefaultMailApplication
{
	BOOL shouldAsk = [[NSUserDefaults standardUserDefaults] boolForKey:AskAgainToBecomeDefaultMailApplication];
	
	if (shouldAsk)
	{		
		if (![self isDefaultMailApplication])
		{
			if (!defaultEmailAppWindow)
			{
				[NSBundle loadNibNamed:@"StandardEmailApp" owner:self];
			}
			
			[defaultEmailAppWindow center];
			[defaultEmailAppWindow makeKeyAndOrderFront:self];
		}		
	}
}

- (void)finishLaunching 
{
	registerDefaultDefaults();
	[super finishLaunching];
	[self askForBecomingDefaultMailApplication];
}

- (IBAction)makeDefaultApp:(id)sender
{
	LSSetDefaultHandlerForURLScheme((CFStringRef)@"mailto", (CFStringRef)[[[NSBundle mainBundle] bundleIdentifier] lowercaseString]);
	[defaultEmailAppWindow close];
}

@end
