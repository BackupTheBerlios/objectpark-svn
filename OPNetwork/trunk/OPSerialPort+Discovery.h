
//  Based on code Copyright (c) 2001 Andreas Mayer.



#import <Cocoa/Cocoa.h>
#import "OPSerialPort.h"

@interface OPSerialPort (Discovery)

+ (NSArray*) availablePorts;

+ (void) updateAvailablePorts;

+ (OPSerialPort*) availablePortWithName: (NSString*) name;

@end
