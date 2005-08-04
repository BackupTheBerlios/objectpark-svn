//
//  NSPersistentObjectContext+Extensions.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 02.08.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OPPersistentObject.h"

@interface OPPersistentObject (Extensions)

+ (NSArray*) allObjects;

- (BOOL) primitiveBoolForKey: (NSString*) key;


@end
