//
//  OPManagedObject.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 01.12.04.
//  Copyright 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class NSManagedObjectContext;

@interface OPManagedObject : NSManagedObject {
}

@end

@interface NSManagedObject (OPExtensions) 

// common methods
- (id) initWithManagedObjectContext: (NSManagedObjectContext*) context;

+ (NSArray*) allObjects;

+ (NSEntityDescription*) entity;

- (void) addValue: (id) value toRelationshipWithKey: (NSString*) key;

@end

