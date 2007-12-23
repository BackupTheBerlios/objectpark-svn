//
//  TestGIMessage.m
//  Gina
//
//  Created by Axel Katerbau on 22.12.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import "TestGIMessage.h"
#import "GIMessage.h"
#import "OPInternetMessage.h"

@implementation TestGIMessage

- (void)testMessageCreation
{
	NSString *transferDataPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestMIMEBoundaries" ofType:@"transferData"];
	NSAssert(transferDataPath != nil, @"couldn't find transferdata resource");
	
	NSData *transferData = [NSData dataWithContentsOfFile:transferDataPath];
	NSAssert(transferData != nil, @"couldn't read transferdata");
	
	OPInternetMessage *internetMessage = [[[OPInternetMessage alloc] initWithTransferData:transferData] autorelease];
	GIMessage *message = [GIMessage messageWithInternetMessage:internetMessage];
	NSAssert(message != nil, @"couldn't create message from internetMessage");
}

@end
