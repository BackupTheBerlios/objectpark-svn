//
//  NSFileHandle+ThreadIO.h
//  OPNetwork
//
//  Created by Dirk Theisen on 15.10.04.
//  Copyright 2004 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

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
