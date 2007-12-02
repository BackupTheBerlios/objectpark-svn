//
//  TestOPMultimediaContentCoder.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 12.04.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "TestOPMultimediaContentCoder.h"
#import "OPMultimediaContentCoder.h"

@implementation TestOPMultimediaContentCoder

- (void) setUp
{
}

- (void) tearDown
{
}

- (void) testCoding 
{
	NSFileWrapper *wrapper, *wrapper1;
	OPMultimediaContentCoder *coder;
	NSAttributedString *attString, *attString1;
	
	NSString *path = [[NSBundle bundleWithIdentifier:@"org.objectpark.InternetMessageTest"] pathForResource:@"MailIcon_queue" ofType:@"tiff"];
	wrapper = [[[NSFileWrapper alloc] initWithPath:path] autorelease];
	
	coder = [[[OPMultimediaContentCoder alloc] initWithFileWrapper:wrapper] autorelease];
	
	wrapper1 = [coder fileWrapper];
	
    NSAssert([[wrapper regularFileContents] isEqual:[wrapper1 regularFileContents]], @"not equal");
	
	attString = [coder attributedString];
	
	coder = [[[OPMultimediaContentCoder alloc] initWithAttributedString:attString] autorelease];
	
	attString1 = [coder attributedString];

	NSAssert([[attString string] isEqual:[attString1 string]], @"not equal");
}

@end
