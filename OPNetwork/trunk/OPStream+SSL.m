//
//  OPSecureStream.m
//  SecureSocket
//
//  Created by joerg on Fri Nov 30 2001.
//  Copyright (c) 2001 Jšrg Westheide. All rights reserved.
//

#import "OPStream+SSL.h"
#import "OPSSLSocket.h"
#import "OPStream+TimeoutExtensions.h"
//#import "OPDebug.h"

@implementation OPStream (SSL)
/*"The SSL category provides methods for handling all SSL related things.

%{ATTENTION: You can only use this category if your stream is based on an OPSSLSocket!}"*/

/*"This method negotiates the SSL encryption.
In normal use of SSL calling this method should be the first to do after making the TCP connect.
Errors are reported as exceptions.
You will receive an exception if the underlying socket does not understand a #{negotiateEncryption} message."*/
- (void) negotiateEncryption
{
    NSAssert([[self fileHandle] respondsToSelector:@selector(negotiateEncryption)], @"Encryption can only be negotiated on secure socket handles");
    //OPDebugLog1(SSLDEBUG, OPINFO, @"negotiating encryption for stream %@", self);
    [((OPSSLSocket*) [self fileHandle]) negotiateEncryption];
}

/*"This method shuts down the SSL encryption.
This has to be done before closing the TCP connection as the other side of the connection will receive an error if you don't.
Error are reported as exceptions.
You will receive an exception if the underlying socket does not understand a #{shutdownEncryption} message."*/
- (void) shutdownEncryption
{
    NSAssert([[self fileHandle] respondsToSelector:@selector(shutdownEncryption)], @"Encryption can only be shut down on secure socket handles");
    //OPDebugLog1(SSLDEBUG, OPINFO, @"shuting down encryption for stream %@", self);
    [((OPSSLSocket*) [self fileHandle]) shutdownEncryption];
}


@end
