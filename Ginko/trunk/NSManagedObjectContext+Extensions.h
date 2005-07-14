//
//  NSManagedObjectContext+Extensions.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 25.01.05.
//  Copyright 2005 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <CoreData/CoreData.h>

@interface NSManagedObjectContext (OPExtensions)

+ (NSManagedObjectContext*) threadContext;
+ (void) setThreadContext: (NSManagedObjectContext*) context;
- (id) objectWithURI: (NSURL*) uri;
+ (id) objectWithURIString: (NSString*) uri;

@end

@interface NSManagedObjectModel (OPExtensions)

- (NSEntityDescription*) entityForClassName: (NSString*) className;

@end
