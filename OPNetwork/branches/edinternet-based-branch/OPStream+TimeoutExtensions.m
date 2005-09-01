//
//  OPStream+TimeoutExtensions.m
//  OPMessageServices
//
//  Created by axel on Wed Nov 28 2001.
//  Copyright (c) 2001 Objectpark Software. All rights reserved.
//

#import "OPStream+TimeoutExtensions.h"
#import "OPSSLSocket.h"

#include <sys/socket.h>

#import <sys/ioctl.h>
#import <sys/types.h>
#import <sys/dir.h>
#import <sys/errno.h>
#import <sys/stat.h>
#import <sys/uio.h>
#import <sys/file.h> 
#import <sys/fcntl.h>
#import <nameser.h>

@implementation OPSocket (TemporaryBugfix)

#ifdef WIN32
#define OPSOCKETHANDLE ((int)[self nativeHandle])
#else
#define OPSOCKETHANDLE [self fileDescriptor]
#endif

#define OP_ERRNO errno


- (void)setSocketOption:(int)option level:(int)level timeValue:(NSTimeInterval)timeout
{
    struct timeval _timeout;
    
    //NSLog(@"OPSocket (TemporaryBugfix)");
    _timeout.tv_sec  = (int)timeout;
    //_timeout.tv_usec = (timeout - (int)timeout) * 1000000;

    _timeout.tv_usec = (int) ((timeout - (int)timeout) * (double)1000);

    if(setsockopt(OPSOCKETHANDLE, level, option, &_timeout, sizeof(_timeout)) == -1)
        [NSException raise:NSFileHandleOperationException format:@"Failed to set option %d on socket: %s", option, strerror(OP_ERRNO)];
}



@end

@implementation OPStream (TimeoutExtensions)

+ (id)streamConnectedToHost:(NSHost *)host port:(unsigned short)port 
{
    OPTCPSocket *socket;
    socket = (id)[[self defaultSocketClass] socket]; 
    [socket connectToHost:host port:port];
    return [self streamWithFileHandle:socket];
}

+ (id)streamConnectedToHost:(NSHost *)host port:(unsigned short)port sendTimeout:(NSTimeInterval)sendTimeout receiveTimeout:(NSTimeInterval)receiveTimeout
{
    id result = [self streamConnectedToHost:host port:port];
    [(OPTCPSocket*)[result fileHandle] setSendTimeout:sendTimeout];
    [(OPTCPSocket*)[result fileHandle] setReceiveTimeout:receiveTimeout];
    return result;
}


+ (id)streamConnectedToHostWithName:(NSString *)hostname port:(unsigned short)port sendTimeout:(NSTimeInterval)sendTimeout receiveTimeout:(NSTimeInterval)receiveTimeout
{
    return [self streamConnectedToHost:[NSHost hostWithName:hostname] port:port sendTimeout:sendTimeout receiveTimeout:receiveTimeout];
}

static Class _defaultSocketClass = Nil;

+ (Class) defaultSocketClass {
    return _defaultSocketClass==Nil ? (_defaultSocketClass=[OPSSLSocket class]) : _defaultSocketClass;
}

+ (void) setDefaultSocketClass: (Class) EDTCPCocketSubclass 
{
    //NSParameterAssert(EDClassIsSuperclassOfClass([OPTCPSocket class], EDTCPCocketSubclass));
    _defaultSocketClass = EDTCPCocketSubclass;
}


@end
