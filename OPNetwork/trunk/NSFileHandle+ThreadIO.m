//
//  NSFileHandle+ThreadIO.m
//  OPNetwork
//
//  Created by Dirk Theisen on 15.10.04.
//  Copyright 2004 __MyCompanyName__. All rights reserved.
//

#import "NSFileHandle+ThreadIO.h"
#import <Foundation/NSDebug.h>
#include <sys/time.h>
#include <unistd.h>



@implementation NSFileHandle (ThreadIO)

static NSMutableDictionary* readTheadsByHandle = nil;

NSMutableDictionary* readThreads()
{
    if (!readTheadsByHandle) readTheadsByHandle = [[NSMutableDictionary alloc] init];
    return readTheadsByHandle;
}


- (void) readInBackgroundThreadAndCallDelegate: (id) delegate
{
    if (delegate) {
        NSAssert(![readThreads() objectForKey: self], @"Only one background reader allowed.");
        
    // Should we retain the delegate?
        [NSThread detachNewThreadSelector: @selector(_readInBackgroundThreadAndCallDelegate:) 
                                 toTarget: self withObject: delegate];
    }
}

- (void) _readInBackgroundThreadAndCallDelegate: (id) delegate
{
    //void *localBuffer;
    //int bytesRead = 0;
    //fd_set *localReadFDs;
    //int fileDescriptor = [self fileDescriptor];
    
    [readThreads() setObject: [NSThread currentThread] forKey: self];
    
    if (NSDebugEnabled) NSLog(@"Started readDataInBackgroundThread: %@", [NSThread currentThread]);
    //localBuffer = malloc(NSFileHandleThreadIOMaxBufferSize);
    //[stopReadInBackgroundLock lock];
    //stopReadInBackground = NO;
	//NSLog(@"stopReadInBackground set to NO: %@", [NSThread currentThread]);
    //[stopReadInBackgroundLock unlock];
	//NSLog(@"attempt readLock: %@", [NSThread currentThread]);
	//[readLock lock];	// write in sequence
        //NSLog(@"readLock locked: %@", [NSThread currentThread]);
    NSAutoreleasePool *localAutoreleasePool = [[NSAutoreleasePool alloc] init];
    //localReadFDs = malloc(sizeof(*localReadFDs));
    //FD_ZERO(localReadFDs);
    //FD_SET(fileDescriptor, localReadFDs);
    //int res = select(fileDescriptor+1, localReadFDs, nil, nil, nil); // timeout);
    BOOL stopReadInBackground = NO;

    
    @try {
        while (!stopReadInBackground) {
            NSData* bytesRead = [self availableData];
            
        //int res = [self ]
        //NSLog(@"attempt closeLock: %@", [NSThread currentThread]);
        //[closeLock lock];
        //NSLog(@"closeLock locked: %@", [NSThread currentThread]);
        //if (/*(res >= 1)*/ && ([self fileDescriptor] >= 0)) {
        //    if (NSDebugEnabled) NSLog(@"attempt read: %@", [NSThread currentThread]);
        //    bytesRead = read(fileDescriptor, localBuffer, NSFileHandleThreadIOMaxBufferSize);
        //}
            if (NSDebugEnabled) NSLog(@"%u bytes of data read:\n%@", [bytesRead length], bytesRead);
            
            if ([bytesRead length]) {
            //if (NSDebugEnabled) NSLog(@"send AMSerialReadInBackgroundDataMessage");
                
                [delegate fileHandle: self 
                            readData: [bytesRead bytes] 
                              length: [bytesRead length]];
            } else {
                stopReadInBackground = YES;
            }
        }
    } @catch (id exception) {
        NSLog(@"Exception during background read (%@). Stopping...", exception);
    }

    if (NSDebugEnabled) NSLog(@"Background read thread stopped: %@", [NSThread currentThread]);
    
    
	//[readLock unlock];
    
    //free(localReadFDs);
    [localAutoreleasePool release];
    //free(localBuffer);
    [readThreads() removeObjectForKey: self];
}

@end

@implementation NSObject (NSFileHandleDelegate)

- (void) fileHandle: (NSFileHandle*) handle
           readData: (const char*) bytes 
             length: (unsigned) byteCount
{
    NSLog(@"%@ received %u bytes of data. Discarding...", handle, byteCount);
}


@end


#if MAC_OS_X_VERSION_10_3 <= MAC_OS_X_VERSION_MAX_ALLOWED

@implementation NSStream (OPExtensions)

- (CFSocketNativeHandle)nativeSocketHandle
{
	return (CFSocketNativeHandle)[self propertyForKey:(NSString *)kCFStreamPropertySocketNativeHandle];
}

@end

#endif