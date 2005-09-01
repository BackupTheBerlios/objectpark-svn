//
//  OPSecureStream.h
//  SecureSocket
//
//  Created by joerg on Fri Nov 30 2001.
//  Copyright (c) 2001 Jšrg Westheide. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OPStream.h"


@interface OPStream (SSL)    

/*"Methods for turning SSL on and off."*/
- (void) negotiateEncryption;
- (void) shutdownEncryption;

@end
