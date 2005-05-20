//
//  OPManagedObject.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 01.12.04.
//  Copyright 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "OPManagedObject.h"
#import "NSManagedObjectContext+Extensions.h"


@implementation NSManagedObject (OPExtensions)

+ (NSEntityDescription*) entity
{
    NSManagedObjectContext *context = [NSManagedObjectContext defaultContext];
    NSEntityDescription* entity = [[[context persistentStoreCoordinator] managedObjectModel] entityForClassName: NSStringFromClass(self)];
    return entity;
}

- (id)initWithManagedObjectContext:(NSManagedObjectContext *)context
/*" Just calls -init if context is nil. "*/
{
    NSParameterAssert(context!=nil);
    
    NSEntityDescription *entity = [[[context persistentStoreCoordinator] managedObjectModel] entityForClassName: NSStringFromClass([self class])];
    
    return [self initWithEntity: entity insertIntoManagedObjectContext: context];
}

- (void) addValue: (id) value toRelationshipWithKey: (NSString*) key
{
    id set = [self valueForKey: key];
    [set addObject: value];
    [self setValue: set forKey: key];
}

+ (NSArray*) allObjects
{
    //#ifdef TIGER
    NSEntityDescription*    entity  = [self entity];
    NSManagedObjectContext* context = [NSManagedObjectContext defaultContext];
    NSFetchRequest*         request = [[[NSFetchRequest alloc] init] autorelease];
    
    [request setEntity:entity];
    NSError *error  = nil;
    NSArray *result = [context executeFetchRequest: request error: &error];
    
    if (error) {
        NSLog(@"Error fetching all objects of %@: %@", self, error);
    }
    /*	
#else
     NSMutableArray *result;
     NSDictionary *objectsAsDictionary;
     NSEnumerator *enumerator;
     NSString *oid;
     
     result = [NSMutableArray array];
     objectsAsDictionary = [[NSManagedObject objectsByClass] objectForKey:NSStringFromClass(aClass)];
     enumerator = [[objectsAsDictionary allKeys] objectEnumerator];
     while (oid = [enumerator nextObject])
     {
         [result addObject:[aClass instanceForId:oid]];
     }
     
#endif
     */
    return result;
}


@end



@implementation OPManagedObject

/*
#ifndef TIGER

static NSMutableDictionary* _objectsByClass = nil;

- (id) objectID
{
    return [self primitiveValueForKey: @"oid"];
}

+ (NSMutableDictionary*) objectsByClass
{
    if (!_objectsByClass) {
        NSString* path = [[NSBundle mainBundle] pathForResource: @"ManagedObjects" ofType: @"plist"];
        if (path) {
            NSString* errStr = nil;
            NSData* data = [NSData dataWithContentsOfFile: path];
            _objectsByClass = [[NSPropertyListSerialization propertyListFromData: data 
                                                                mutabilityOption: NSPropertyListMutableContainers
                                                                          format: NULL
                                                                errorDescription: &errStr] retain];
            if (errStr)
                NSLog(@"Error: %@", errStr);
        }
    }
    return _objectsByClass;
}



+ (NSMutableArray*) makeInstancesInArray: (NSMutableArray*) ids
{
    if (ids) {
        int i;
        for (i = [ids count]-1;i>=0;i--) {
            id someId = [ids objectAtIndex: i];
            if (![someId isKindOfClass: self]) {
                [ids replaceObjectAtIndex: i withObject: [self instanceForId: someId]];
            }
        }
    }
    return ids;
}

+ (id) instanceForId: (id) someId
{
    if (!someId) return nil;
    NSMutableDictionary* instances = [[self objectsByClass] objectForKey: NSStringFromClass(self)];
    id result = [instances objectForKey: someId];
    // turn instances into 
    if (![result isKindOfClass: self]) {
        [result setObject: someId forKey: @"oid"];
        result = [(NSManagedObject*)[self alloc] initWithDictionary: result];
        [instances setObject: result forKey: someId];
        [result release];
    }
    return result;
}



- (id) initWithDictionary: (NSMutableDictionary*) dict
{
    if (self = [self init]) {
        ivs = [dict retain];
    }
    return self;
}

- (id) primitiveValueForKey: (NSString*) key
{
    return [ivs objectForKey: key];
}

- (void) setPrimitiveValue: (id) value forKey: (NSString*) key
{
    if (!ivs) ivs = [[NSMutableDictionary alloc] init];
    if (value)
        [ivs setObject: value forKey: key];
    else
        [ivs removeObjectForKey: key];
}

- (id) valueForUndefinedKey: (NSString*) key
{
    id result = [self primitiveValueForKey: key];
    if (!result) 
        NSLog(@"Warning: value for key %@ not defined on managed object of class %@.", key, [self class]);
    return result;
}

- (void) setValue: (id) value forKey: (NSString*) key
{
    [self setPrimitiveValue: value forKey: key];
}

- (void) willAccessValueForKey: (NSString*) key
{
    
}

- (void) willChangeValueForKey: (NSString*) key 
{
    
}

- (void) didAccessValueForKey: (NSString*) key
{
    
}

- (void) didChangeValueForKey: (NSString*) key
{
    
}


- (NSString*) description
{
    return [NSString stringWithFormat: @"%@ with managed id '%@'", [super description], [self objectID]];
}

- (void) dealloc
{
    [ivs release];
    // Remove self as observer:
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    [super dealloc];
}

#endif
*/
@end
