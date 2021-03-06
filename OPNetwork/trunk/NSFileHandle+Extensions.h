//---------------------------------------------------------------------------------------
//  NSFileHandle+NetExt.h created by erik
//  @(#)$Id: NSFileHandle+Extensions.h,v 1.3 2004/10/14 13:38:19 theisen Exp $
//
//  Copyright (c) 1997 by Erik Doernenburg. All rights reserved.
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


#ifndef	__NSFileHandle_NetExt_h_INCLUDE
#define	__NSFileHandle_NetExt_h_INCLUDE


#import <Foundation/Foundation.h>

// documentation in .m file

@interface NSFileHandle(EDExtensions)

/*" Endpoints for socket handles "*/

- (unsigned short)localPort;
- (NSString *)localAddress;

- (unsigned short)remotePort;
- (NSString *)remoteAddress;
- (NSHost *)remoteHost;

/*" Shutdown "*/

- (void)shutdown;
- (void)shutdownInput;
- (void)shutdownOutput;

/*" Non-blocking reads, e.g. on sockets "*/

- (NSData *)availableDataNonBlocking;
- (NSData *)readDataToEndOfFileNonBlocking;
- (NSData *)readDataOfMaxLengthNonBlocking:(unsigned int)length;

/**
 * Call -writeInBackgroundAndNotify:forModes: with nil modes.
 */
- (void) writeInBackgroundAndNotify: (NSData*)item;

/**
 * Write the specified data asynchronously, and notify on completion.
 */
- (void) writeInBackgroundAndNotify: (NSData*) item forModes: (NSArray*) modes;

@end

// GNUstep Notification names.

/**
* Notification posted when an asynchronous [NSFileHandle] connection
 * attempt (to an FTP, HTTP, or other internet server) has succeeded.
 */
extern NSString * const GSFileHandleConnectCompletionNotification;

/**
* Notification posted when an asynchronous [NSFileHandle] write
 * operation (to an FTP, HTTP, or other internet server) has succeeded.
 */
extern NSString * const GSFileHandleWriteCompletionNotification;

/**
* Message describing error in asynchronous [NSFileHandle] accept,read,write
 * operation.
 */
extern NSString * const GSFileHandleNotificationError;


#endif	/* __NSFileHandle_NetExt_h_INCLUDE */
