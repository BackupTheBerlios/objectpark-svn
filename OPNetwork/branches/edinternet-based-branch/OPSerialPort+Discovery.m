
//  Based on code Copyright (c) 2001 Andreas Mayer.

#import "OPSerialPort+Discovery.h"
#import "OPSerialPort.h"

#include <termios.h>

#include <CoreFoundation/CoreFoundation.h>

#include <IOKit/IOKitLib.h>
#include <IOKit/serial/IOSerialKeys.h>
#include <IOKit/IOBSD.h>

//static OPSerialPortList* OPSerialPortListSoliton = nil;

static 	NSMutableArray* portList = nil;
static  NSArray* oldPortList = nil;

/*
@interface OPSerialPortList (Private)

- (NSArray*) oldPortList;
- (void) setOldPortList: (NSArray*) newOldPortList;

@end
*/


@implementation OPSerialPort (Discovery)


// ---------------------------------------------------------
// - setOldPortList:
// ---------------------------------------------------------
static void setOldPortList(NSArray* newOldPortList)
{
    id old = nil;

    if (newOldPortList != oldPortList) {
        old = oldPortList;
        oldPortList = [newOldPortList retain];
        [old release];
    }
}

static OPSerialPort* oldPortByPath(NSString* bsdPath)
{
	OPSerialPort *result = nil;
	OPSerialPort *object;
	NSEnumerator *enumerator;

	enumerator = [oldPortList objectEnumerator];
	while (object = [enumerator nextObject]) {
		if ([[object bsdPath] isEqualToString:bsdPath]) {
			result = object;
			break;
		}
	}
	return result;
}

static kern_return_t findSerialPorts(io_iterator_t* matchingServices)
{
    kern_return_t		kernResult; 
    mach_port_t			masterPort;
    CFMutableDictionaryRef	classesToMatch;

    kernResult = IOMasterPort(MACH_PORT_NULL, &masterPort);
    if (KERN_SUCCESS != kernResult)
    {
        //printf("IOMasterPort returned %d\n", kernResult);
    }
        
    // Serial devices are instances of class IOSerialBSDClient
    classesToMatch = IOServiceMatching(kIOSerialBSDServiceValue);
    if (classesToMatch == NULL)
    {
        //printf("IOServiceMatching returned a NULL dictionary.\n");
    }
    else
        CFDictionarySetValue(classesToMatch,
                            CFSTR(kIOSerialBSDTypeKey),
                            CFSTR(kIOSerialBSDAllTypes));
    
    kernResult = IOServiceGetMatchingServices(masterPort, classesToMatch, matchingServices);    
    if (KERN_SUCCESS != kernResult)
    {
        //printf("IOServiceGetMatchingServices returned %d\n", kernResult);
    }
        
    return kernResult;
}


static OPSerialPort* getNextSerialPort(io_iterator_t serialPortIterator)
{
    io_object_t		serialService;
    OPSerialPort	*result = nil;
    
    if ((serialService = IOIteratorNext(serialPortIterator)))
    {
        CFTypeRef	modemNameAsCFString;
        CFTypeRef	bsdPathAsCFString;

        modemNameAsCFString = IORegistryEntryCreateCFProperty(serialService,
                                                              CFSTR(kIOTTYDeviceKey),
                                                              kCFAllocatorDefault,
                                                              0);
        bsdPathAsCFString = IORegistryEntryCreateCFProperty(serialService,
                                                            CFSTR(kIOCalloutDeviceKey),
                                                            kCFAllocatorDefault,
                                                            0);
        if (modemNameAsCFString && bsdPathAsCFString) {
            result =  oldPortByPath((NSString*)bsdPathAsCFString);
            if (result == nil)
                result = [[OPSerialPort alloc] init:(NSString *)bsdPathAsCFString withName:(NSString *)modemNameAsCFString];
        }

        if (modemNameAsCFString)
            CFRelease(modemNameAsCFString);
            
        if (bsdPathAsCFString)
            CFRelease(bsdPathAsCFString);
    
        IOObjectRelease(serialService);
        // We have sucked this service dry of information so release it now.
        return result;
    }
    else
        return NULL;
}


+ (void) updateAvailablePorts
/*" Call this to update the cached list of available ports. They may come and go. "*/
{
    kern_return_t	kernResult; // on PowerPC this is an int (4 bytes)
    /*
     *	error number layout as follows (see mach/error.h):
     *
     *	hi		 		       lo
     *	| system(6) | subsystem(12) | code(14) |
     */
    io_iterator_t	serialPortIterator;
    OPSerialPort	*serialPort;
    
    if (portList != nil) {
        setOldPortList([NSArray arrayWithArray:portList]);
        [portList removeAllObjects];
    } else {
        portList = [[NSMutableArray alloc] init];
    }
    kernResult = findSerialPorts(&serialPortIterator);
    do { 
        serialPort = getNextSerialPort(serialPortIterator);
        if (serialPort != NULL) {
            [portList addObject:serialPort];
        }
    } while (serialPort != NULL);
    
    IOObjectRelease(serialPortIterator);	// Release the iterator.
    setOldPortList(nil);
}

+ (NSArray*) availablePorts;
{
    if (!portList) [self updateAvailablePorts];
    return [[portList copy] autorelease];
}


+ (OPSerialPort*) availablePortWithName: (NSString*) name
{
    NSEnumerator* e = [[self availablePorts] objectEnumerator];
    OPSerialPort* port;
    while (port = [e nextObject]) {
        if ([[port name] isEqualToString: name]) {
            return port;
        }
    }
    return nil;
}


@end
