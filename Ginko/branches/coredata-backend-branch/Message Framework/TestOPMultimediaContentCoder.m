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

- (void)setUp
{
}

- (void)tearDown
{
}

- (void)testCoding 
{
	NSFileWrapper *wrapper, *wrapper1;
	OPMultimediaContentCoder *coder;
	NSAttributedString *attString, *attString1;
	
	wrapper = [[[NSFileWrapper alloc] initWithPath:[[NSBundle mainBundle] pathForResource:@"MailIcon_queue" ofType:@"tiff"]] autorelease];
	
	coder = [[[OPMultimediaContentCoder alloc] initWithFileWrapper:wrapper] autorelease];
	
	wrapper1 = [coder fileWrapper];
	
    shouldBeEqual([wrapper regularFileContents], [wrapper1 regularFileContents]);
	
	attString = [coder attributedString];
	
	coder = [[[OPMultimediaContentCoder alloc] initWithAttributedString:attString] autorelease];
	
	attString1 = [coder attributedString];

	shouldBeEqual([attString string], [attString1 string]);
}

@end
