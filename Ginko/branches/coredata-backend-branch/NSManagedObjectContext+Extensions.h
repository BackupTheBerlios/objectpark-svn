//
//  NSManagedObjectContext+Extensions.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 25.01.05.
//  Copyright 2005 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <CoreData/CoreData.h>

NSArray* objectIdsForObjects(NSSet* aSet);

@interface NSManagedObjectContext (OPExtensions)

+ (NSManagedObjectContext*) threadContext;
+ (void) setMainThreadContext: (NSManagedObjectContext*) aContext;
+ (NSManagedObjectContext*) mainThreadContext;

- (id) objectWithURI: (NSURL*) uri;
+ (id) objectWithURIString: (NSString*) uri;
+ (void) resetThreadContext;
- (void) refreshObjectsWithObjectIDs: (NSArray*) ids;

@end

@interface NSManagedObjectModel (OPExtensions)

- (NSEntityDescription*) entityForClassName: (NSString*) className;

@end
