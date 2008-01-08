//
//  OPSMTP+InternetMessage.m
//  Gina
//
//  Created by Axel Katerbau on 03.03.06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "OPSMTP+InternetMessage.h"
#import "OPInternetMessage.h"
#import "EDTextFieldCoder.h"
#import "NSString+MessageUtils.h"
#import "NSData+MessageUtils.h"
#import <Foundation/NSDebug.h>

@implementation OPSMTP (InternetMessage)

/* The receiver will consume 'message' if willing and able to (cf. -willAcceptMessage). Raises
an exception if the 'message' will not be consumed. */
- (void)sendMessage:(OPInternetMessage *)message
{
    NSArray *authors;
    NSString *newRecipients;
	NSString *sender;
	NSString *bccBody;
    NSData *transferData;
    EDTextFieldCoder *coder = nil;
    
    if (! [self willAcceptMessage])
        [NSException raise:NSInvalidArgumentException format:@"-[%@ %@]: SMTP server will not accept messages.", NSStringFromClass(isa), NSStringFromSelector(_cmd)];
    
    NSMutableArray *recipients = [NSMutableArray array];
    if (newRecipients = [message bodyForHeaderField:@"To"]) {
        coder = [[EDTextFieldCoder alloc] initWithFieldBody:newRecipients];
        [recipients addObjectsFromArray:[[coder text] addressListFromEMailString]];
        NSLog(@"recipients = %@", recipients);
        [coder release];
    }
    
    if (newRecipients = [message bodyForHeaderField:@"Cc"]) {
        coder = [[EDTextFieldCoder alloc] initWithFieldBody:newRecipients];
        [recipients addObjectsFromArray:[[coder text] addressListFromEMailString]];
        [coder release];
    }
    
    if (bccBody = [message bodyForHeaderField:@"Bcc"])
    {
        coder = [[EDTextFieldCoder alloc] initWithFieldBody:bccBody];
        [recipients addObjectsFromArray: [[coder text] addressListFromEMailString]];
        [coder release];
    }
    
    if (! [recipients count])
        [NSException raise:NSInvalidArgumentException format:@"-[%@ %@]: No recipients in message headers.", NSStringFromClass(isa), NSStringFromSelector(_cmd)];
    
    coder = nil; // guarantee that coder is harmless
    
    if (sender = [message bodyForHeaderField:@"Sender"]) {
        coder = [[EDTextFieldCoder alloc] initWithFieldBody:sender];
        sender = [coder text];
    }
    
    if (! sender)
    {
        NSString *fromField;
        
        [coder release];
        
        fromField = [message bodyForHeaderField:@"From"];
        authors = nil;
        
        if (fromField = [message bodyForHeaderField:@"From"]) {
            coder = [[EDTextFieldCoder alloc] initWithFieldBody:fromField];
            
            authors = [[coder text] addressListFromEMailString];
        }
        
        if (! [authors count]) {
            [NSException raise:NSInvalidArgumentException format:@"-[%@ %@]: No sender or from field in message headers.", NSStringFromClass(isa), NSStringFromSelector(_cmd)];
        }
        
        if ([authors count] > 1) {
            [NSException raise:NSInvalidArgumentException format:@"-[%@ %@]: Multiple from addresses and no sender field in message headers.", NSStringFromClass(isa), NSStringFromSelector(_cmd)];
        }
        sender = [authors objectAtIndex:0];
    }
    
    [coder release];
    
    if ([[message contentTransferEncoding] isEqualToString:MIME8BitContentTransferEncoding]) {
        // we could try to recode the "offending" parts using Quoted-Printable and Base64...
        if (! [self handles8BitBodies]) {
            [NSException raise:NSInvalidArgumentException format:@"-[%@ %@]: Message has 8-bit content transfer encoding but remote MTA only accepts 7-bit.", NSStringFromClass(isa), NSStringFromSelector(_cmd)];
        }
    }
    
    if (bccBody) {
        [message removeHeaderField:@"Bcc"];
        if (NSDebugEnabled) NSLog(@"Bcc removed.");
    }
    
    @try {
        transferData = [message transferData];
        [self sendTransferData:transferData from:sender to:recipients];
    } @catch (id localException) {
        if (bccBody) {
            [message setBody:bccBody forHeaderField:@"Bcc"];
        }
		@throw;
	}
    
    if (bccBody) {
        [message setBody: bccBody forHeaderField:@"Bcc"];
    }
}

@end
