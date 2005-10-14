//
//  NSPersistentObjectContext+Extensions.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 02.08.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "OPPersistence.h"

@interface OPPersistentObject (OPExtensions)

+ (NSArray*) allObjects;

- (BOOL) primitiveBoolForKey: (NSString*) key;


@end

@interface OPPersistentObjectContext (OPExtensions)

+ (OPPersistentObjectContext*) threadContext;
+ (void) setMainThreadContext: (OPPersistentObjectContext*) aContext;
+ (OPPersistentObjectContext*) mainThreadContext;

- (OPPersistentObject*) objectWithURL: (NSURL*) url;
+ (OPPersistentObject*) objectWithURL: (NSURL*) url;

@end