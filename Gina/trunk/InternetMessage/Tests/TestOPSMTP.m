//
//  TestOPSMTP.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 25.03.05.
//  Copyright (c) 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "TestOPSMTP.h"
#import "OPSMTP.h"
#import <OPNetwork/OPStream+SSL.h>
#import "NSString+MessageUtils.h"
#import "OPInternetMessage.h"
#import "OPSMTP+InternetMessage.h"

@implementation TestOPSMTP

- (void) setUp
{
}

- (void) tearDown
{
}

- (OPInternetMessage *)makeAMessage
{
    static int i = 1;
    NSString *messageId = [NSString stringWithFormat: @"<smtptest-message-%d@test.org>",i++];
	NSString *recipient = [[[NSUserDefaults standardUserDefaults] persistentDomainForName:@"org.objectpark.InternetMessageTest"] objectForKey:@"SMTPTestRecipient"];
    NSAssert(recipient != nil, @"SMTP test recipient must be specified in 'org.objectpark.InternetMessageTest' User Default with key 'SMTPTestRecipient'.");
	
	NSString *sender = [[[NSUserDefaults standardUserDefaults] persistentDomainForName:@"org.objectpark.InternetMessageTest"] objectForKey:@"SMTPTestUser"];
    NSAssert(sender != nil, @"SMTP test user must be specified in 'org.objectpark.InternetMessageTest' User Default with key 'SMTPTestUser'.");
	
    NSString *transferString = [NSString stringWithFormat:
                                             @"Message-ID: %@\r\nDate: Fri, 16 Nov 2001 09:51:25 +0100\r\nTo: %@\r\nFrom: %@\r\nMIME-Version: 1.0\r\nSubject: SMTP-Test\r\nReferences: <Pine.LNX.4.33.0111151839560.23892-100000@bla.com\r\nContent-Type: text/plain; charset=us-ascii\r\nContent-Transfer-Encoding: 7bit\r\nNewsgroups: gnu.gnustep.discuss\r\n\r\nUlf Licht wrote:\r\n", messageId, recipient, sender];
    NSData *transferData = [transferString dataUsingEncoding:NSASCIIStringEncoding];
    STAssertNotNil(transferData, @"nee");
    
    OPInternetMessage *message = [[[OPInternetMessage alloc] initWithTransferData:transferData] autorelease];
    STAssertNotNil(message, @"nee %@", messageId);
    STAssertTrue([[message messageId] isEqual: messageId], @"nee");
    
    return message;
}

- (void)testSMTPConnect
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    OPSMTP *SMTP = nil;
    NSHost *host;
    OPStream *smtpStream;
	
	NSLog(@"bundle id = %@", [NSBundle mainBundle]);
	NSString *hostName = [[[NSUserDefaults standardUserDefaults] persistentDomainForName:@"org.objectpark.InternetMessageTest"] objectForKey:@"SMTPTestHost"];	
    NSAssert(hostName != nil, @"SMTP test hostname must be specified in 'org.objectpark.InternetMessageTest' User Default with key 'SMTPTestHost'.");
    
    host = [NSHost hostWithName:hostName];
    NSAssert(host != nil, @"host error");
    
    smtpStream = [OPStream streamConnectedToHost:host port:25 sendTimeout:30.0 receiveTimeout:30.0];
    NSAssert(smtpStream != nil, @"stream error");
    //NSLog(@"smtpStream = %@", smtpStream);

	SMTP = [OPSMTP SMTPWithStream:smtpStream andDelegate:self];
    NSAssert(SMTP != nil, @"SMTP error");

	[SMTP connect];
    [SMTP sendMessage:[self makeAMessage]];
    
    [smtpStream close];
    [pool release];
}

- (NSString *)usernameForSMTP:(OPSMTP *)aSMTP
{
	NSString *username = [[[NSUserDefaults standardUserDefaults] persistentDomainForName:@"org.objectpark.InternetMessageTest"] objectForKey:@"SMTPTestUser"];
	
    NSAssert(username != nil, @"SMTP test user must be specified in 'org.objectpark.InternetMessageTest' User Default with key 'SMTPTestUser'.");
    return username;
}

- (NSString *)passwordForSMTP:(OPSMTP *)aSMTP
{
	NSString *password = [[[NSUserDefaults standardUserDefaults] persistentDomainForName:@"org.objectpark.InternetMessageTest"] objectForKey:@"SMTPTestPassword"];
	
    NSAssert(password != nil, @"SMTP test password must be specified in 'org.objectpark.InternetMessageTest' User Default with key 'SMTPTestPassword'.");
    return password;
}

- (BOOL)allowAnyRootCertificateForSMTP:(OPSMTP *)aSMTP
{
	return YES;
}

@end
