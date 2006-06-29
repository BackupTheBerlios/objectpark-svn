//
//  TestNSString+Extensions.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 27.06.06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "TestNSString+Extensions.h"
#import "NSString+Extensions.h"


@implementation TestNSStringExtensions

- (void) testHTMLStripping
{
	NSString* html = @"<b>This<b> is our <a href=\"http://www.objectpark.net\">h&ouml;me page</a>.";
	
	NSString* text = [html stringByStrippingHTML];
	
	text = text;
}

+ (void) testHTMLStrip
{
	NSString* html = @"<b>This<b> is our <a href=\"http://www.objectpark.net\">h&ouml;me page</a>.";
	
	NSString* text = [html stringByStrippingHTML];
	
	text = text;
}


@end
