//---------------------------------------------------------------------------------------
//  OPIPSocket.m created by erik
//  @(#)$Id: OPIPSocket.m,v 1.5 2004/10/13 15:55:28 theisen Exp $
//
//  Copyright (c) 1997-2001 by Erik Doernenburg. All rights reserved.
//
//  Permission to use, copy, modify and distribute this software and its documentation
//  is hereby granted, provided that both the copyright notice and this permission
//  notice appear in all copies of the software, derivative works or modified versions,
//  and any portions thereof, and that both notices appear in supporting documentation,
//  and that credit is given to Erik Doernenburg in all documents and publicity
//  pertaining to direct or indirect use of this code or its derivatives.
//
//  THIS IS EXPERIMENTAL SOFTWARE AND IT IS KNOWN TO HAVE BUGS, SOME OF WHICH MAY HAVE
//  SERIOUS CONSEQUENCES. THE COPYRIGHT HOLDER ALLOWS FREE USE OF THIS SOFTWARE IN ITS
//  "AS IS" CONDITION. THE COPYRIGHT HOLDER DISCLAIMS ANY LIABILITY OF ANY KIND FOR ANY
//  DAMAGES WHATSOEVER RESULTING DIRECTLY OR INDIRECTLY FROM THE USE OF THIS SOFTWARE
//  OR OF ANY DERIVATIVE WORK.
//---------------------------------------------------------------------------------------

#import <Foundation/Foundation.h>
#include "osdep.h"
#include "functions.h"
#include "NSFileHandle+Extensions.h"
#include "OPIPSocket.h"

@interface OPIPSocket(PrivateAPI)
- (void)_connectToAddress:(NSString *)hostAddress port:(unsigned short)port hostDescription:(NSString *)hostDesc;
@end

#ifdef WIN32
#define OPSOCKETHANDLE ((int)[self nativeHandle])
#else
#define OPSOCKETHANDLE [self fileDescriptor]
#endif

#define EDSOCK_HOSTDESCFORADDR NSLocalizedString(@"with the address %@", "Description for a host in error messages when the connection was attempted to a specific IP address. Hope this is localisable because it assumes a specific context, e.g. 'the computer _with_the_address_127.0.0.1_ refused...'")

#define EDSOCK_ECONNREFUSED NSLocalizedString(@"The computer %@ refused connection on port %d.", "Message for ECONNREFUSED returned from connect.")

#define EDSOCK_ETIMEDOUT NSLocalizedString(@"Timeout when connecting to the computer %@.", "Message for ETIMEDOUT returned from connect.")

#define EDSOCK_ENETDOWN NSLocalizedString(@"Attempt to connect to a the computer %@ failed because the computer's network is down.", "Message for ENETDOWN returned from connect.")

#define EDSOCK_ENETUNREACH NSLocalizedString(@"Attempt to connect to the computer %@ failed because the computer's network cannot be reached.", "Message for ENETUNREACH returned from connect.")

#define EDSOCK_EHOSTDOWN NSLocalizedString(@"Attempt to connect to the computer %@ failed because it is currently inactive.", "Message for EHOSTDOWN returned from connect.")

#define EDSOCK_EHOSTUNREACH NSLocalizedString(@"Attempt to connect to the computer %@ failed because no route to it is avaiable.", "Message for EHOSTUNREACH returned from connect.")

#define EDSOCK_EOTHER NSLocalizedString(@"Attempt to connect to %@ on port %d failed due to an unexpected error: %s (%d)", "Generic message for errors returned from connect.")


//---------------------------------------------------------------------------------------
    @implementation OPIPSocket
//---------------------------------------------------------------------------------------

/*" This class provides methods for basic IP funtionality: binding to a port, connecting to an address, setting popular socket options, etc. It is not meant to be instantiated, though. This is left to its two sublasses #OPTCPSocket and #EDUDPSocket.

Note that some (IP) socket related functionality is implemented in a category on NSFileHandle. "*/

NSString *EDSocketTemporaryConnectionFailureException = @"EDSocketTemporaryConnectionFailureException";
NSString *EDSocketConnectionRefusedException = @"EDSocketConnectionRefusedException";


//---------------------------------------------------------------------------------------
//	CLASS ATTRIBUTES
//---------------------------------------------------------------------------------------

+ (int)protocolFamily
{
    return PF_INET;
}


//---------------------------------------------------------------------------------------
//	INIT & DEAlLOC
//---------------------------------------------------------------------------------------

- (void)dealloc
{
   if(flags.connectState > 0)
       [self closeFile];
   [super dealloc];
}


//---------------------------------------------------------------------------------------
//	OPTIONS & PARAMETERS
//---------------------------------------------------------------------------------------

/*" Controls whether broadcast messages are allowed. This corresponds to !{SO_BROADCAST}. "*/
- (void)setAllowsTransmittingBroadcastMessages:(BOOL)flag
{
    [self setSocketOption:SO_BROADCAST level:SOL_SOCKET value:flag];
}


/*" Controls how quickly an address/port combination can be re-used. With this option set a socket can be connected to a port that is still in !{TIME_WAIT} state which is useful if your server has been shut down, and then restarted right away while sockets are still active on its port. You should be aware that if any unexpected data comes in, it may confuse your server, but while this is possible, it is not likely. This corresponds to !{SO_REUSEADDR}. "*/

- (void)setAllowsAddressReuse:(BOOL)flag
{
    [self setSocketOption:SO_REUSEADDR level:SOL_SOCKET value:flag];
}


/*" Controls whether the address/port combination can be shared by multiple sockets. Note that all sockets sharing the address/port must have this option set for it to work. This corresponds !{SO_REUSEPORT} and is currently only implemented on Apple platforms even though other BSD and BSD-derived systems should support it. Note that for multicast addresses this is considered synonymous to !{SO_REUSEADDR} ("TCP/IP Illustrated, Volume 2", p. 731.) So, for portability of multicasting applications you should use #{setAllowsAddressReuse:} instead. "*/

#ifdef __APPLE__
- (void)setAllowsPortReuse:(BOOL)flag
{
    [self setSocketOption:SO_REUSEPORT level:SOL_SOCKET value:flag];
}
#endif


/*" Sets the timeout for send (write) operations to aTimeoutVal. This corresponds to !{SO_SNDTIMEO}. "*/

- (void)setSendTimeout:(NSTimeInterval)aTimeoutVal
{
    [self setSocketOption:SO_SNDTIMEO level:SOL_SOCKET timeValue:aTimeoutVal];
}


/*" Sets the timeout for receive (read) operations to aTimeoutVal. This corresponds to !{SO_RCVTIMEO}. "*/

- (void)setReceiveTimeout:(NSTimeInterval)aTimeoutVal
{
    [self setSocketOption:SO_RCVTIMEO level:SOL_SOCKET timeValue:aTimeoutVal];
}


// The next method is for compatibility only

- (void)setLocalPortNumber:(unsigned short)port
{
    static int setLocalPortNumberDidLog = 0;
    
    if(setLocalPortNumberDidLog == 0)
        {
        setLocalPortNumberDidLog = 1;
        NSLog(@"** method -setLocalPortNumber: in class OPIPSocket is obsolete. Please use -setLocalPort:");
        }
    [self setLocalPort:port];
}


/*" Binds the local endpoint of the socket to %aPort on all local IP addresses (interfaces). "*/

- (void)setLocalPort:(unsigned short)aPort
{
    struct in_addr anyAddress;
    
    anyAddress.s_addr = htonl(INADDR_ANY); 
    [self setLocalPort:aPort andAddress:OPStringFromInAddr(anyAddress)];
}


/*" Binds the local endpoint of the socket to %aPort on the local IP address described by %addressString; the latter being in the "typical" dotted numerical notation. "*/

- (void)setLocalPort:(unsigned short)aPort andAddress:(NSString *)addressString
{
    struct sockaddr_in socketAddress;

    memset(&socketAddress, 0, sizeof(struct sockaddr_in));
    socketAddress.sin_family = AF_INET;
    socketAddress.sin_addr = OPInAddrFromString(addressString);
    socketAddress.sin_port = htons(aPort);

    if(bind(OPSOCKETHANDLE, (struct sockaddr *)&socketAddress, sizeof(socketAddress)) == -1)
        [NSException raise:NSFileHandleOperationException format:@"Binding of socket to port %d failed: %s", (int)aPort, strerror(OP_ERRNO)];
}


//---------------------------------------------------------------------------------------
//	CONNECTION SETUP AND SHUTDOWN
//---------------------------------------------------------------------------------------

/*" Attempts to connect the remote endpoint of the socket to port on host. "*/

- (void)connectToHost:(NSHost *)host port:(unsigned short)port
{
    NSException 	*firstTemporaryException = nil;
    NSEnumerator 	*hostAddressEnumerator;
    NSString		*hostAddress, *hostDesc;
    BOOL			sawV4Address;

    NSAssert(flags.connectState == 0, @"already connected");

    sawV4Address = NO;
    hostAddressEnumerator = [[host addresses] objectEnumerator];
    while((flags.connectState == 0) && (hostAddress = [hostAddressEnumerator nextObject]))
        {
        if([hostAddress rangeOfString:@":"].length > 0)
            continue; // can't deal with IPv6 addresses yet
        sawV4Address = YES;
        NS_DURING
            hostDesc = [NSString stringWithFormat:@"%@ (%@)", [host name], hostAddress];
            [self _connectToAddress:hostAddress port:port hostDescription:hostDesc];
        NS_HANDLER
            if(([[localException name] isEqualToString:EDSocketConnectionRefusedException] == NO) && ([[localException name] isEqualToString:EDSocketTemporaryConnectionFailureException] == NO))
                [localException raise];
            if(firstTemporaryException == nil)
                firstTemporaryException = [[localException retain] autorelease];
        NS_ENDHANDLER
        }

    if(sawV4Address == NO)
        [NSException raise:NSInvalidArgumentException format:@"Host %@ has no IPv4 address.", host];

    if(flags.connectState == 0)
        [firstTemporaryException raise];
}


/*" Attempts to connect the remote endpoint of the socket to port on the host with the IP address described by %addressString; the latter being in the "typical" dotted numerical notation. "*/

- (void)connectToAddress:(NSString *)addressString port:(unsigned short)port
{
    [self _connectToAddress:addressString port:port hostDescription:[NSString stringWithFormat:EDSOCK_HOSTDESCFORADDR, addressString]];
}

- (void) connectToInAddr: (struct sockaddr_in*) socketAddress 
         hostDescription: (NSString*) hostDesc
{
    struct sockaddr* sa = (struct sockaddr *)socketAddress;
    if(connect(OPSOCKETHANDLE, sa, sizeof(struct sockaddr_in)) < 0) 
    {
        unsigned short port = socketAddress->sin_port;
        if (!hostDesc) 
            hostDesc = OPStringFromInAddr(socketAddress->sin_addr);
        
        switch(OP_ERRNO)
        {
            case ECONNREFUSED:
                [NSException raise:EDSocketConnectionRefusedException format:EDSOCK_ECONNREFUSED, hostDesc, port];
                break;
                
            case ETIMEDOUT:
                [NSException raise:EDSocketTemporaryConnectionFailureException format:EDSOCK_ETIMEDOUT, hostDesc, port];
                break;
                
            case ENETDOWN:
                [NSException raise:EDSocketTemporaryConnectionFailureException format:EDSOCK_ENETDOWN, hostDesc, port];
                break;
                
            case ENETUNREACH:
                [NSException raise:EDSocketTemporaryConnectionFailureException format:EDSOCK_ENETUNREACH, hostDesc, port];
                break;	
                
            case EHOSTDOWN:
                [NSException raise:EDSocketTemporaryConnectionFailureException format:EDSOCK_EHOSTDOWN, hostDesc, port];
                break;
                
            case EHOSTUNREACH:
                [NSException raise:EDSocketTemporaryConnectionFailureException format:EDSOCK_EHOSTUNREACH, hostDesc, port];
                break;
                
            default:
                [NSException raise:NSFileHandleOperationException format:EDSOCK_EOTHER, hostDesc, port, strerror(OP_ERRNO), OP_ERRNO];
                break;
        }	
    }
    flags.connectState = 3;    
}


- (void) _connectToAddress: (NSString *)hostAddress 
                      port: (unsigned short)port 
           hostDescription: (NSString *)hostDesc
{
    struct sockaddr_in 	socketAddress;
    
    NSAssert(flags.connectState == 0, @"already connected");
    
    memset(&socketAddress, 0, sizeof(struct sockaddr_in));
    socketAddress.sin_family = AF_INET;
    socketAddress.sin_addr = OPInAddrFromString(hostAddress);
    socketAddress.sin_port = htons(port);
    [self connectToInAddr: &socketAddress hostDescription: hostDesc];
}

- (void) connectToNetService: (NSNetService*) aService
{
    NSData* address;  
    struct sockaddr*    some_socket_adr = NULL;
    struct sockaddr_in* socketAddress   = NULL;
    
    // Iterate through addresses until we find an IPv4 address
    NSEnumerator *addressEnum = [[aService addresses] objectEnumerator];
    
    while (address = [addressEnum nextObject]) {
        some_socket_adr = (struct sockaddr *)[address bytes];
        if (some_socket_adr->sa_family == AF_INET) {
            socketAddress = (struct sockaddr_in*)some_socket_adr;
            break;
        }
    }
    
    NSAssert(socketAddress, @"NetService did not contain any valid socket address.");
    //if (!socketAddress) return NO; Throw exception?
    //socketAddress->sin_port = 80; // Test only!!
    [self connectToInAddr: socketAddress hostDescription: nil];
}


/*" Returns YES if the socket allows communication, either in both directions or only sending or receiving; the latter resulting from #shutdownInput or #shutdownOutput invocations. (These are implemented in a category on #NSFileHandle.) It only returns NO if the socket is completely disconnected. "*/

- (BOOL)isConnected
{
    return (flags.connectState > 0);
}


// Semantics for connectState:
// 	0 - disconnected
//	1 - only receives allowed
//	2 - only sends allowed
//	3 - fully connected

- (void)shutdown
{
    [super shutdown];
    flags.connectState = 0;
}


- (void)shutdownInput
{
    [super shutdownOutput];
    flags.connectState &= ~1;
}


- (void)shutdownOutput
{
    [super shutdownOutput];
    flags.connectState &= ~2;
}


- (void)closeFile
{
    if(flags.connectState > 0)
        {
        shutdown(OPSOCKETHANDLE, flags.connectState - 1);
        flags.connectState = 0;
        }
    [super closeFile];
}


//---------------------------------------------------------------------------------------
    @end
//---------------------------------------------------------------------------------------
