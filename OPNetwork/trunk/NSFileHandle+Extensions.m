//---------------------------------------------------------------------------------------
//  NSFileHandle+NetExt.m created by erik
//  @(#)$Id: NSFileHandle+Extensions.m,v 1.4 2004/10/13 15:55:28 theisen Exp $
//
//  Copyright (c) 1997,1999 by Erik Doernenburg. All rights reserved.
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

#ifdef WIN32
#import <System/windows.h>  // move this to osdep.h?
#endif

#ifdef WIN32
#define OPSOCKETHANDLE ((int)[self nativeHandle])
#else
#define OPSOCKETHANDLE [self fileDescriptor]
#endif

//---------------------------------------------------------------------------------------
    @implementation NSFileHandle(EDExtensions)
//---------------------------------------------------------------------------------------

/*" Various useful extensions to #NSFileHandle. Most only work with file handles that represent sockets but this is in a category on NSFileHandle, and not in its subclass #OPIPSocket, because this functionality is also useful for plain NSFileHandles that represent sockets. The latter are often created through invocations such as #acceptConnectionInBackgroundAndNotify. "*/


/*" Returns the port of the local endpoint of the socket. "*/

- (unsigned short)localPort
{
    socklen_t 		   sockaddrLength;
    struct sockaddr_in sockaddr;
    
    sockaddrLength = sizeof(struct sockaddr_in);
    if(getsockname(OPSOCKETHANDLE, (struct sockaddr *)&sockaddr, &sockaddrLength) == -1)
        [NSException raise:NSFileHandleOperationException format:@"Cannot get local port number for socket: %s", strerror(OP_ERRNO)];
    return sockaddr.sin_port;
}


/*" Returns the address of the local endpoint of the socket in the "typical" dotted numerical notation. "*/

- (NSString *)localAddress
{
    socklen_t 		   sockaddrLength;
    struct sockaddr_in sockaddr;
    
    sockaddrLength = sizeof(struct sockaddr_in);
    if(getsockname(OPSOCKETHANDLE, (struct sockaddr *)&sockaddr, &sockaddrLength) == -1)
        [NSException raise:NSFileHandleOperationException format:@"Cannot get local port number for socket: %s", strerror(OP_ERRNO)];
    return OPStringFromInAddr(sockaddr.sin_addr);
}


/*" Returns the port of the remote endpoint of the socket. "*/

- (unsigned short)remotePort
{
    socklen_t 		   sockaddrLength;
    struct sockaddr_in sockaddr;

    sockaddrLength = sizeof(struct sockaddr_in);
    if(getpeername(OPSOCKETHANDLE, (struct sockaddr *)&sockaddr, &sockaddrLength) == -1)
        [NSException raise:NSFileHandleOperationException format:@"Failed to get peer: %s", strerror(OP_ERRNO)];
    return sockaddr.sin_port;
}


/*" Returns the address of the remote endpoint of the socket in the "typical" dotted numerical notation. "*/

- (NSString *)remoteAddress
{
    socklen_t 		   sockaddrLength;
    struct sockaddr_in sockaddr;

    sockaddrLength = sizeof(struct sockaddr_in);
    if(getpeername(OPSOCKETHANDLE, (struct sockaddr *)&sockaddr, &sockaddrLength) == -1)
        [NSException raise:NSFileHandleOperationException format:@"Failed to get peer: %s", strerror(OP_ERRNO)];
    return OPStringFromInAddr(sockaddr.sin_addr);
}


/*" Returns the host for the remote endpoint of the socket. "*/

- (NSHost *)remoteHost
{
    return [NSHost hostWithAddress:[self remoteAddress]];
}


/*" Causes the full-duplex connection on the socket to be shut down. "*/

- (void)shutdown
{
    if(shutdown(OPSOCKETHANDLE, 2) == -1)
        [NSException raise:NSFileHandleOperationException format:@"Failed to shutdown socket: %s", strerror(OP_ERRNO)];
}


/*" Causes part of the full-duplex connection on the socket to be shut down; further receives will be disallowed. "*/

- (void)shutdownInput
{
    if(shutdown(OPSOCKETHANDLE, 0) == -1)
        [NSException raise:NSFileHandleOperationException format:@"Failed to shutdown input of socket: %s", strerror(OP_ERRNO)];
}


/*" Causes part of the full-duplex connection on the socket to be shut down; further sends will be disallowed. "*/

- (void)shutdownOutput
{
    if(shutdown(OPSOCKETHANDLE, 1) == -1)
        [NSException raise:NSFileHandleOperationException format:@"Failed to shutdown output of socket: %s", strerror(OP_ERRNO)];
}


- (unsigned int)_availableByteCountNonBlocking
{
#ifdef WIN32
    DWORD lpTotalBytesAvail;
    BOOL peekSuccess;

    peekSuccess = PeekNamedPipe(OPSOCKETHANDLE, NULL, 0L, NULL, &lpTotalBytesAvail, NULL);

    if (peekSuccess == NO)
        [NSException raise: NSFileHandleOperationException
                    format: @"PeekNamedPipe() NT Error # %d", GetLastError()];

    return lpTotalBytesAvail;
#elif defined(__APPLE__) || defined(__FreeBSD__) || defined(linux)
    int numBytes;

    if(ioctl(OPSOCKETHANDLE, FIONREAD, (char *) &numBytes) == -1)
        [NSException raise: NSFileHandleOperationException
                    format: @"ioctl() error # %d", errno];

    return numBytes;
#else
#warning Non-blocking I/O not supported on this platform....
    abort();
    return 0;
#endif
}


/*" Calls #{readDataOfMaxLengthNonBlocking:} with a length of !{UINT_MAX}, effectively reading as much data as is available. "*/

- (NSData *)availableDataNonBlocking
{
    return [self readDataOfMaxLengthNonBlocking:UINT_MAX];
}

/*" Calls #{readDataOfMaxLengthNonBlocking:} with a length of !{UINT_MAX}, effectively reading as far towards the end of the file as possible. "*/

- (NSData *)readDataToEndOfFileNonBlocking
{
    return [self readDataOfMaxLengthNonBlocking:UINT_MAX];
}


/*" Tries to read length bytes of data. If less data is available it does not block to wait for more but returns whatever is available. If no data is available this method returns !{nil} and not an empty instance of #NSData. "*/

- (NSData *)readDataOfMaxLengthNonBlocking:(unsigned int)length
{
    unsigned int available;

    available = [self _availableByteCountNonBlocking];
    if(available == 0)
        return nil;

    return [self readDataOfLength:((available < length) ? available : length)];
}


//---------------------------------------------------------------------------------------
    @end
//---------------------------------------------------------------------------------------
