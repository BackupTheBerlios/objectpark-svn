//
//  $Id:OPLogMock.h$
//  OPDebug
//
//  Created by Jörg Westheide on 26.10.2005.
//  Copyright 2005 Objectpark.org. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "OPLog.h"


@interface OPLogMock : OPLog {
    NSString *loggedMessage;
}

+ (OPLogMock*) sharedInstance;

- (void) log:(NSString*)aMessage;

- (NSString*) loggedMessage;

@end
