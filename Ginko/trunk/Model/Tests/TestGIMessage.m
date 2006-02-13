//
//  TestGIMessage.m
//  GinkoVoyager
//
//  Created by Jörg Westheide on 07.02.2006.
//  Copyright (c) 2006 Objectpark.org. All rights reserved.
//

#import "TestGIMessage.h"
#import "GIMessage.h"


@implementation TestGIMessage

#pragma mark Helper

- (GIMessage*) makeMessageWithId:(NSString*)messageId andReferences:(NSString*)references
{
    NSString *transferString;
    if (references)
        transferString = [NSString stringWithFormat:@"Message-ID: %@\r\nReferences: %@\r\n\r\nbody\r\n", messageId, references];
    else
        transferString = [NSString stringWithFormat:@"Message-ID: %@\r\n\r\nbody\r\n", messageId];
        
    NSData *transferData = [transferString dataUsingEncoding:NSASCIIStringEncoding];
    STAssertNotNil(transferData, @"Could not create the transfer data for message with id %@ and references %@", messageId, references);
    
    GIMessage *message = [GIMessage messageWithTransferData:transferData];
    STAssertNotNil(message, @"Could not create message for id %@ from transfer data %@", messageId, transferData);
    STAssertTrue([[message messageId] isEqual:messageId], @"Message has a wrong message id");
    
    return message;
}


#pragma mark tests for -referenceFind:

- (void) testReferenceFind_doNotCreateAReference
{
    GIMessage* message = [self makeMessageWithId:@"<3>" andReferences:@"<1> <2>"];
    STAssertNotNil(message, @"Creating message failed");
    
    GIMessage* ref = [message referenceFind:NO];
    NSAssert(ref == nil, @"Reference returned although finding was disallowed");
}


- (void) testReferenceFind_createWithoutReference
{
    GIMessage* message = [self makeMessageWithId:@"<1>" andReferences:nil];
    STAssertNotNil(message, @"Creating message failed");
    
    GIMessage* ref = [message referenceFind:NO];
    NSAssert(ref == nil, @"Reference returned although finding was not allowed and there is none");
    ref = [message referenceFind:YES];
    NSAssert(ref == nil, @"Reference returned although there is none");
}


@end
