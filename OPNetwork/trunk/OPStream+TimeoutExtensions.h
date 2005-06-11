//
//  OPStream+TimeoutExtensions.h
//  OPMessageServices
//
//  Created by axel on Wed Nov 28 2001.
//  Copyright (c) 2001 Objectpark Software. All rights reserved.
//

#import <Foundation/NSFileHandle.h>
#import "OPStream.h"

@interface OPStream (TimeoutExtensions) 

+ (id)streamConnectedToHost:(NSHost *)host port:(unsigned short)port sendTimeout:(NSTimeInterval)sendTimeout receiveTimeout:(NSTimeInterval)receiveTimeout;

+ (id)streamConnectedToHostWithName:(NSString *)hostname port:(unsigned short)port sendTimeout:(NSTimeInterval)sendTimeout receiveTimeout:(NSTimeInterval)receiveTimeout;

+ (id)streamConnectedToHost:(NSHost *)host port:(unsigned short)port;

/* This factory allows OPStream subclasses to force a certain socket subclass as default. */
+ (Class) defaultSocketClass;

+ (void) setDefaultSocketClass: (Class) EDTCPCocketSubclass;

@end
