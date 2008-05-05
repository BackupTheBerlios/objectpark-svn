//
//  GIMailAddressTokenFieldDelegate.h
//  Gina
//
//  Created by Axel Katerbau on 28.04.08.
//  Copyright 2008 Objectpark Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface GIMailAddressTokenFieldDelegate : NSObject 
{

}

+ (void)addToLRUMailAddresses:(NSString *)anAddressString;
+ (void)removeFromLRUMailAddresses:(NSString *)anAddressString;

@end
