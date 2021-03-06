//
//  TestWithPersistence.m
//  Gina
//
//  Created by Axel Katerbau on 24.12.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import "TestWithPersistence.h"
#import "OPPersistence.h"
#import "GIMessage.h"
#import "OPInternetMessage.h"

@implementation TestWithPersistence

- (void)setUp
{
	if (! [OPPersistentObjectContext defaultContext]) {
		OPPersistentObjectContext *context = [[OPPersistentObjectContext alloc] init];
		[[NSFileManager defaultManager] removeFileAtPath: @"/tmp/persistent-testobjects.btrees" handler: nil];
		[context setDatabaseFromPath: @"/tmp/persistent-testobjects.btrees"];
		[OPPersistentObjectContext setDefaultContext: context];
	}
}

- (void) tearDown
{
	[[OPPersistentObjectContext defaultContext] reset];
	//[[NSFileManager defaultManager] removeFileAtPath: @"/tmp/persistent-testobjects.btrees" handler: nil];
}

+ (GIMessage*) newMessageForTest
{
	NSString *transferDataPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestMIMEBoundaries" ofType:@"transferData"];
	NSAssert(transferDataPath != nil, @"couldn't find transferdata resource");
	
	NSData *transferData = [NSData dataWithContentsOfFile:transferDataPath];
	NSAssert(transferData != nil, @"couldn't read transferdata");
	
	OPInternetMessage *internetMessage = [[[OPInternetMessage alloc] initWithTransferData:transferData] autorelease];
	GIMessage *message = [[GIMessage alloc] initWithInternetMessage: internetMessage appendToAppropriateThread: NO forcedMessageId: nil];
	NSAssert(message != nil, @"couldn't create message from internetMessage");

	return message;
}


- (void) testTransferDataPersistence
{
	OPPersistentObjectContext* context = [OPPersistentObjectContext defaultContext];
	GIMessage* msgIn = [[self class] newMessageForTest];
	[context insertObject: msgIn];
	[context saveChanges];
	OID oid = [msgIn oid];
	[msgIn release];
	[context reset];
	GIMessage* msgOut = [context objectForOID: oid];
	NSAssert(msgOut.internetMessage, @"Unable to retrieve internet message for GIMessage.");
}

@end
