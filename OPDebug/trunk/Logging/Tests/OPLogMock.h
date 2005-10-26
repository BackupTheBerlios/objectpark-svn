//
//  $Id:OPLogMock.h$
//  OPDebug
//
//  Created by Jörg Westheide on 26.10.2005.
//  Copyright 2005 Objectpark.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "OPDebugLog.h"


@interface OPLogMock : OPDebugLog {
    NSString *loggedMessage;
}

+ (OPLogMock*) sharedInstance;

- (void) log:(NSString*)aMessage;

- (NSString*) loggedMessage;

@end
