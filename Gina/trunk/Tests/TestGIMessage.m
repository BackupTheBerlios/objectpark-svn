//
//  TestGIMessage.m
//  Gina
//
//  Created by Axel Katerbau on 22.12.07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "TestGIMessage.h"
#import "GIMessage.h"

@implementation TestGIMessage

- (void)testMessageCreation
{
	NSString *transferDataPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestMIMEBoundaries" ofType:@"transferData"];
	NSAssert(transferDataPath != nil, @"couldn't find transferdata resource");
	
	NSData *transferData = [NSData dataWithContentsOfFile:transferDataPath];
	NSAssert(transferData != nil, @"couldn't read transferdata");
	
	GIMessage *message = [GIMessage messageWithTransferData:transferData];
	NSAssert(message != nil, @"couldn't create message from transferdata");
}

@end
