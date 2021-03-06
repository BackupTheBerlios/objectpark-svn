//
//  TestOPAppleDoubleContentCoder.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 13.04.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "TestOPAppleDoubleContentCoder.h"
#import "OPAppleDoubleContentCoder.h"

@implementation TestOPAppleDoubleContentCoder

- (void)setUp
{
}

- (void)tearDown
{
}

- (void)testCoding 
{
	NSFileWrapper *wrapper, *wrapper1;
	OPAppleDoubleContentCoder *coder;
	NSAttributedString *attString, *attString1;
	
	wrapper = [[[NSFileWrapper alloc] initWithPath:[[NSBundle mainBundle] pathForResource:@"MailIcon_queue" ofType:@"tiff"]] autorelease];
	
	coder = [[[OPAppleDoubleContentCoder alloc] initWithFileWrapper:wrapper] autorelease];
	
	wrapper1 = [coder fileWrapper];
	
    shouldBeEqual([wrapper regularFileContents], [wrapper1 regularFileContents]);
	
	attString = [coder attributedString];
	
	coder = [[[OPAppleDoubleContentCoder alloc] initWithAttributedString:attString] autorelease];
	
	attString1 = [coder attributedString];
	
	shouldBeEqual([attString string], [attString1 string]);
}

@end
