//
//  $Id:OPLogMock.m$
//  OPDebug
//
//  Created by Jörg Westheide on 26.10.2005.
//  Copyright 2005 Objectpark.org. All rights reserved.
//

#import "OPLogMock.h"


@implementation OPLogMock
/*"This class mocks the logger class and provides an accessor to the last logged
   message.
   To make it work one has to ensure that the +sharedInstance method is called
   before the original +sharedInstance method is called so that the mock object
   is used as the shared instance."*/

+ (OPLogMock*) sharedInstance
    {
    return (OPLogMock*) [super sharedInstance];
    }
    
    
- (void) log:(NSString*)aMessage
    {
    [loggedMessage autorelease];
    loggedMessage = [aMessage retain];
    }
    
    
/*"Returns the last logged message."*/
- (NSString*) loggedMessage;
    {
    return loggedMessage;
    }
    
@end
