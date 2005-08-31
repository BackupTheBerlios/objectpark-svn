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

+ (void)lockStore
{
    [[[NSManagedObjectContext threadContext] persistentStoreCoordinator] lock];
}

+ (void)unlockStore
{
    [[[NSManagedObjectContext threadContext] persistentStoreCoordinator] unlock];
}

+ (NSEntityDescription*) entity
{
    NSManagedObjectContext *context = [NSManagedObjectContext threadContext];
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
    NSEntityDescription*    entity  = [self entity];
    NSManagedObjectContext* context = [NSManagedObjectContext threadContext];
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

