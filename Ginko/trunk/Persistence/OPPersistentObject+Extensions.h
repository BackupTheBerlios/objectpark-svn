//
//  NSPersistentObjectContext+Extensions.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 02.08.05.
//  Copyright 2005 The Objectpark Group. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "OPPersistence.h"

@interface OPPersistentObject (OPExtensions)

+ (NSEnumerator*) allObjectsEnumerator;

- (BOOL) primitiveBoolForKey: (NSString*) key;

@end

@interface OPPersistentObjectContext (OPExtensions)

+ (OPPersistentObjectContext*) threadContext;
+ (void) setMainThreadContext: (OPPersistentObjectContext*) aContext;
+ (OPPersistentObjectContext*) mainThreadContext;
+ (id) objectWithURLString: (NSString*) url;

@end

@interface NSError (OPExtensions)

+ (id) errorWithDomain: (NSString*) domain description: (NSString*) description;

@end