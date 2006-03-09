//
//  OPSerialPort.h
//  CommX
//
//  Created by Andreas on 2002-04-24.
//  Copyright (c) 2001 Andreas Mayer. All rights reserved.
//
//  2002-09-18 Andreas Mayer
//  - added available & owner
//  2002-10-17 Andreas Mayer
//	- countWriteInBackgroundThreads and countWriteInBackgroundThreadsLock added
//  2002-10-25 Andreas Mayer
//	- more additional instance variables for reading and writing in background
//  2004-02-10 Andreas Mayer
//    - added delegate for background reading/writing


/*
 * Standard speeds defined in termios.h
 *
#define B0	0
#define B50	50
#define B75	75
#define B110	110
#define B134	134
#define B150	150
#define B200	200
#define B300	300
#define B600	600
#define B1200	1200
#define	B1800	1800
#define B2400	2400
#define B4800	4800
#define B7200	7200
#define B9600	9600
#define B14400	14400
#define B19200	19200
#define B28800	28800
#define B38400	38400
#define B57600	57600
#define B76800	76800
#define B115200	115200
#define B230400	230400
 */


#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <paths.h>
#include <termios.h>
#include <sys/time.h>
#include <sysexits.h>
#include <sys/param.h>

#import <Foundation/Foundation.h>

#define	AMSerialOptionServiceName @"AMSerialOptionServiceName"
#define	AMSerialOptionSpeed @"AMSerialOptionSpeed"
#define	AMSerialOptionDataBits @"AMSerialOptionDataBits"
#define	AMSerialOptionParity @"AMSerialOptionParity"
#define	AMSerialOptionStopBits @"AMSerialOptionStopBits"
#define	AMSerialOptionInputFlowControl @"AMSerialOptionInputFlowControl"
#define	AMSerialOptionOutputFlowControl @"AMSerialOptionOutputFlowControl"
#define	AMSerialOptionEcho @"AMSerialOptionEcho"


@interface OPSerialPort : NSObject
{
	char *bsdPath;
	NSString *serviceName;
	//int fileDescriptor;
	struct termios *options;
	struct termios *originalOptions;
	NSMutableDictionary *optionsDictionary;
	NSFileHandle *fileHandle;
	int lastError;
	id owner;
	// used by AMSerialPortAdditions only:
	char *buffer;
	NSTimer *readTimer;
	id readTarget;
	SEL readSelector;
	struct timeval *timeout;
	fd_set *readfds;
	//id delegate;
	//BOOL delegateHandlesReadInBackground;
	//BOOL delegateHandlesWriteInBackground;
	
	NSLock *writeLock;
	//BOOL stopWriteInBackground;
	NSLock *stopWriteInBackgroundLock;
	//int countWriteInBackgroundThreads;
	NSLock *countWriteInBackgroundThreadsLock;
	NSLock *readLock;
	BOOL stopReadInBackground;
	NSLock *stopReadInBackgroundLock;
	//int countReadInBackgroundThreads;
	NSLock *countReadInBackgroundThreadsLock;
	NSLock *closeLock;
}

- (id)init:(NSString *)path withName:(NSString *)name;
// initializes port
// path is a bsdPath
// name is an IOKit service name

- (NSString *)bsdPath;
// returns the bsdPath (e.g. '/dev/cu.modem')

- (NSString*) name;
// returns tho IOKit service name (e.g. 'modem')

- (BOOL) isOpen;
// YES if port is open

- (OPSerialPort*) obtainBy: (id) sender;
// get this port exclusively; NULL if it's not free

- (void) free;
// give it back (and close the port if still open)

- (BOOL) available;
// check if port is free and can be obtained

- (id)owner;
// who obtained the port?

- (NSFileHandle*) fileHandle;

- (NSFileHandle*) open;
// opens port for read and write operations
// to actually read or write data use the methods provided by NSFileHandle
// (alternatively you may use those from AMSerialPortAdditions)

- (void)close;
// close port - no more read or write operations allowed

- (void) drainInput;
- (void) flushInput: (BOOL) fIn Output: (BOOL) fOut;	// (fIn or fOut) must be YES
- (void) sendBreak;

// read and write serial port settings through a dictionary

- (NSDictionary*) getOptions;
// will open the port to get options if neccessary

- (void) setOptions: (NSDictionary*) options;
// AMSerialOptionServiceName HAS to match! You may NOT switch ports using this
// method.

// reading and setting parameters is only useful if the serial port is already open
- (long) getSpeed;
- (void) setSpeed:(long)speed;

- (int) getDataBits;
- (void) setDataBits:(int)bits;	// 5 to 8 (5 may not work)

- (BOOL) testParity;		// NO for "no parity"
- (BOOL) testParityOdd;		// meaningful only if TestParity == YES
- (void) setParityNone;
- (void) setParityEven;
- (void) setParityOdd;

- (int) getStopBits;
-(void) setStopBits2:(BOOL)two;	// one else

- (BOOL) testEchoEnabled;
- (void) setEchoEnabled:(BOOL)echo;

- (BOOL) testRTSInputFlowControl;
- (void) setRTSInputFlowControl:(BOOL)rts;

- (BOOL) testDTRInputFlowControl;
- (void) setDTRInputFlowControl:(BOOL)dtr;

- (BOOL) testCTSOutputFlowControl;
- (void) setCTSOutputFlowControl:(BOOL)cts;

- (BOOL) testDSROutputFlowControl;
- (void) setDSROutputFlowControl:(BOOL)dsr;

- (BOOL) testCAROutputFlowControl;
- (void) setCAROutputFlowControl:(BOOL)car;

- (BOOL) testHangupOnClose;
- (void) setHangupOnClose:(BOOL)hangup;

- (BOOL) getLocal;
- (void) setLocal:(BOOL)local;	// YES = ignore modem status lines

- (BOOL) commitChanges;		// call this after using any of the above Set functions
- (int) errorCode;		// if CommitChanges returns NO, look here for further info
- (const char*) errorString;

// setting the delegate (for background reading/writing)

//- (id)delegate;
//- (void)setDelegate:(id)newDelegate;

- (BOOL) readString: (const unsigned char*) str;
- (void) writeString: (const unsigned char*) str;
- (void) writeBytes: (const unsigned char*) bytes length: (unsigned) len;


@end
