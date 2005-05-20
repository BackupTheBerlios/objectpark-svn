//
//  OPManagedObject.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 01.12.04.
//  Copyright 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class NSManagedObjectContext;

#ifndef TIGER

@interface NSManagedObject : NSObject {
    NSMutableDictionary* ivs;
}


- (void) willAccessValueForKey: (NSString*) key;
- (void) willChangeValueForKey: (NSString*) key;
- (void) didAccessValueForKey: (NSString*) key;
- (void) didChangeValueForKey: (NSString*) key;

- (id) initWithDictionary: (NSMutableDictionary*) dict;

- (id) primitiveValueForKey: (NSString*) key;

- (void) setPrimitiveValue: (id) value forKey: (NSString*) key;

@end
#endif

@interface OPManagedObject : NSManagedObject {
}

#ifndef TIGER

+ (NSMutableDictionary*) objectsByClass;

+ (id) instanceForId: (id) someId;

+ (NSMutableArray*) makeInstancesInArray: (NSMutableArray*) ids;

#endif

@end

@interface NSManagedObject (OPExtensions) 

// common methods
- (id) initWithManagedObjectContext: (NSManagedObjectContext*) context;

+ (NSArray*) allObjects;

+ (NSEntityDescription*) entity;

- (void) addValue: (id) value toRelationshipWithKey: (NSString*) key;

@end

