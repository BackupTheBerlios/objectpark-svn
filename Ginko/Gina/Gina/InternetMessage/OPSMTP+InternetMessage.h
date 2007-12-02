//
//  OPSMTP+InternetMessage.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 03.03.06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OPSMTP.h"

@class OPInternetMessage;

@interface OPSMTP (InternetMessage)

- (void)sendMessage:(OPInternetMessage *)message;

@end
