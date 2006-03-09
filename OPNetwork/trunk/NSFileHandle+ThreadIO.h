//
//  NSFileHandle+ThreadIO.h
//  OPNetwork
//
//  Created by Dirk Theisen on 15.10.04.
//  Copyright 2004 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#define	NSFileHandleThreadIOMaxBufferSize 4096

@interface NSObject (NSFileHandleDelegate)

- (void) fileHandle: (NSFileHandle*) handle
           readData: (const char*) bytes 
             length: (unsigned) byteCount;

//- (void)serialPortWriteProgress: (NSDictionary*)dataDictionary;

@end

@interface NSFileHandle (ThreadIO)

- (void) readInBackgroundThreadAndCallDelegate: (id) delegate;


@end

#if MAC_OS_X_VERSION_10_3 <= MAC_OS_X_VERSION_MAX_ALLOWED

@interface NSStream (OPExtensions)

- (CFSocketNativeHandle) nativeSocketHandle;

@end

#endif