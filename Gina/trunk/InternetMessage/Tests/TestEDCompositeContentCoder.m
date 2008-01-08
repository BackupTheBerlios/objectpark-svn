//
//  TestEDCompositeContentCoder.m
//  Gina
//
//  Created by Axel Katerbau on 12.12.06.
//  Copyright (c) 2006 Objectpark Group. All rights reserved.
//

#import "TestEDCompositeContentCoder.h"
#import "EDCompositeContentCoder.h"
#import "EDMessagePart.h"

@implementation TestEDCompositeContentCoder

- (void)testMIMEBoundaries
{
	NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestMIMEBoundaries" ofType:@"transferData"];
	NSAssert(path != nil, @"Path to transfer data resource not found. Fatal error.");
	NSData *data = [NSData dataWithContentsOfFile:path];
	NSAssert1(data != nil, @"Could not read data at path: %@", path);
	
	EDMessagePart *part = [[[EDMessagePart alloc] initWithTransferData:data] autorelease];
	EDCompositeContentCoder *coder = nil;
	
	@try
	{
		coder = [[[EDCompositeContentCoder alloc] initWithMessagePart:part] autorelease];
	}
	@catch (id localException)
	{
		NSLog(@"Exception: %@", [localException reason]);
	}

	STAssertNotNil(coder, @"Coder could not be initialized.");
}

@end
