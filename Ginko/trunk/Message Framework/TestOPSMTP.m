//
//  TestOPSMTP.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 25.03.05.
//  Copyright (c) 2005 __MyCompanyName__. All rights reserved.
//

#import "TestOPSMTP.h"
#import "OPSMTP.h"
#import <OPNetwork/OPStream+SSL.h>
#import "NSString+MessageUtils.h"

@implementation TestOPSMTP

- (void)setUp
{
}

- (void)tearDown
{
}

- (void)testSMTPConnect
{
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

    SMTP = [[OPSMTP alloc] initWithStream:smtpStream andDelegate:self];
    NSAssert(SMTP != nil, @"SMTP error");
    NSLog(@"SMTP = %@", SMTP);
  
    /*
    [SMTP acceptMessage:aMessage];
    */
    [SMTP release];
    [smtpStream close];
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
