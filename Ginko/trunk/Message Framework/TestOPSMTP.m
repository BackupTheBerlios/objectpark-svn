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
#import "GIMessage.h"
#import "OPPersistentObject+Extensions.h"

@implementation TestOPSMTP

- (void)setUp
{
}

- (void)tearDown
{
    [[OPPersistentObjectContext threadContext] rollback];
}

- (GIMessage *)makeAMessage
{
    static int i = 1;
    NSString *messageId = [NSString stringWithFormat:@"<smtptest-message-%d@test.org>",i++];
    NSString *transferString = [NSString stringWithFormat:
                                             @"Message-ID: %@\r\nDate: Fri, 16 Nov 2001 09:51:25 +0100\r\nTo: axel@objectpark.org\r\nFrom: axel@xn--heinz-knig-kcb.de\r\nMIME-Version: 1.0\r\nSubject: SMTP-Test\r\nReferences: <Pine.LNX.4.33.0111151839560.23892-100000@bla.com\r\nContent-Type: text/plain; charset=us-ascii\r\nContent-Transfer-Encoding: 7bit\r\nNewsgroups: gnu.gnustep.discuss\r\n\r\nUlf Licht wrote:\r\n", messageId];
    NSData *transferData = [transferString dataUsingEncoding:NSASCIIStringEncoding];
    STAssertNotNil(transferData, @"nee");
    
    GIMessage *message = [GIMessage messageWithTransferData:transferData];
    STAssertNotNil(message, @"nee %@", messageId);
    STAssertTrue([[message messageId] isEqual:messageId], @"nee");
    
    return message;
}

- (void)testSMTPConnect
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    OPSMTP *SMTP;
    NSHost* host;
    OPStream *smtpStream;
    NSString *hostName;
    
    hostName = [@"mail.xn--heinz-knig-kcb.de" IDNAEncodedDomainName];
    NSAssert(hostName != nil, @"hostName error");
    NSLog(@"hostName = %@", hostName);
    
    host = [NSHost hostWithName:hostName];
    NSAssert(host != nil, @"host error");
    NSLog(@"host = %@", host);
    
    smtpStream = [OPStream streamConnectedToHost:host port:25 sendTimeout:30.0 receiveTimeout:30.0];
    NSAssert(smtpStream != nil, @"stream error");
    NSLog(@"smtpStream = %@", smtpStream);

    NSAssert(SMTP != nil, @"SMTP error");
    NSLog(@"SMTP = %@", SMTP);
  
    [SMTP acceptMessage:[[self makeAMessage] internetMessage]];
    
    [SMTP release];
    [smtpStream close];
    [pool release];
}

- (NSString *)usernameForSMTP:(OPSMTP *)aSMTP
{
    return @"axel@xn--heinz-knig-kcb.de";
}

- (NSString *)passwordForSMTP:(OPSMTP *)aSMTP
{
    return @"axelTest";
}

@end
