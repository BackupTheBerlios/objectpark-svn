//
//  NSManagedObjectContext+Extensions.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 25.01.05.
//  Copyright 2005 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "NSManagedObjectContext+Extensions.h"
#import "GIApplication.h"

@implementation NSManagedObjectContext (OPExtensions)

static volatile NSThread* mainThread = nil;

+ (NSManagedObjectContext*) threadContext
{
    NSManagedObjectContext *result;
    NSMutableDictionary* threadDict = [[NSThread currentThread] threadDictionary];

    result = [threadDict objectForKey:@"OPDefaultManagedObjectContext"];
    if (!result) {
        NSAssert(mainThread!=[NSThread currentThread], @"Need a mainThreadContext before any threadContext can be inqired.");
        
        NSManagedObjectContext* mainContext = [[mainThread threadDictionary] objectForKey:@"OPDefaultManagedObjectContext"];
        NSPersistentStoreCoordinator* psc = [mainContext persistentStoreCoordinator];
        result = [[NSManagedObjectContext alloc] init];
        [result setUndoManager: nil];
        [result setPersistentStoreCoordinator: psc];

        [threadDict setObject: result forKey: @"OPDefaultManagedObjectContext"];
        [result release];
    }
    
    NSAssert (result != nil, @"+[NSManagedObject (Extensions) threadContext]: context returned should never be nil");
    return result;
}

+ (void) setMainThreadContext: (NSManagedObjectContext*) aContext
{
    NSMutableDictionary* threadDict = [[NSThread currentThread] threadDictionary];
    if (aContext) {
        [threadDict setObject:aContext forKey: @"OPDefaultManagedObjectContext"];
    } else {
        [threadDict removeObjectForKey: @"OPDefaultManagedObjectContext"];
    }
    mainThread = [NSThread currentThread];
    [aContext setUndoManager: nil];
}

+ (void) resetThreadContext
{
        // todo: save persistent store coordinator when currentThread==mainThread

    NSMutableDictionary* threadDict = [[NSThread currentThread] threadDictionary];
    [threadDict removeObjectForKey: @"OPDefaultManagedObjectContext"];
}

- (id) objectWithURI: (NSURL*) uri
{
    if (uri) {
        NSManagedObjectID *moid = [[self persistentStoreCoordinator] managedObjectIDForURIRepresentation: uri];
        
        if (moid && !([moid isTemporaryID])) // no temporary ids allowed
        {
            return [self objectWithID: moid];
        }
    }
    
    return nil;
}

+ (NSManagedObjectContext*) mainThreadContext
    /*" Use carefully. "*/
{
    NSDictionary* threadDict = [mainThread threadDictionary];
    NSManagedObjectContext* result = [threadDict objectForKey:@"OPDefaultManagedObjectContext"];
    return result;
}

+ (id) objectWithURIString: (NSString*) uri
/*" Returns the  object for the uri given in the default context. "*/
{
    return [[self threadContext] objectWithURI: [NSURL URLWithString: uri]];
}

- (void) refreshObjectsWithObjectIDs: (NSArray*) ids
{
    NSEnumerator* e = [ids objectEnumerator];
    NSManagedObjectID* oid;
    BOOL ownObjectsAffected = NO;
    while (oid = [e nextObject]) {
        NSManagedObject* object = [self objectRegisteredForID: oid];
        if (object) {
            if (!([object isDeleted]) && !([object isFault])) 
            {
                NSLog(@"refreshing object %@", object);
                [self refreshObject: object mergeChanges: YES]; 
                //[self refreshObject: object mergeChanges: NO]; 
                ownObjectsAffected = YES;
            }
        }
    }
    if (ownObjectsAffected) {
        NSError* error = nil;
        
        [self save: &error];
        if (error) 
            NSLog(@"Error after merge: %@", error);
    }
}

- (void) mergeObjectsWithIds: (NSArray*) ids
{
    //NSLog(@"Will merge objects with ids: %@", ids);
    [self refreshObjectsWithObjectIDs: ids];
}

NSArray* objectIdsForObjects(NSSet* aSet)
{
    NSMutableArray* result = [NSMutableArray array];
    NSEnumerator* e = [aSet objectEnumerator];
    NSManagedObject* object;
    while (object = [e nextObject]) {
        [result addObject: [object objectID]];
    }
    return result;
}

+ (void) objectsDidChange2: (NSNotification*) notification
{
    if (mainThread!=[NSThread currentThread]) {
        //NSManagedObjectContext* nContext = [notification object];
        NSSet* changedObjects = [[notification userInfo] objectForKey: NSUpdatedObjectsKey];
        //NSLog(@"%d Objects did change in %@ (background thread %@)", [changedObjects count], nContext, [NSThread currentThread]);
        [[self mainThreadContext] performSelectorOnMainThread: @selector(mergeObjectsWithIds:) withObject: objectIdsForObjects(changedObjects) waitUntilDone: NO];

    }
}

@end

@implementation NSManagedObjectModel (OPExtensions)

- (NSEntityDescription*) entityForClassName: (NSString*) className
{
    // Should probably in a subclass so we can have the cache as instance variable and clear the cache whenever the entities array changes.
    id result = nil;
    static id sself = nil;
    static NSMutableDictionary* cache = nil;
    if (sself!=self) {
        // clear cache
        [cache release];
        cache = [[NSMutableDictionary alloc] init];
        sself = self;
    } else {
        // ask cache:
        result = [cache objectForKey: className];
    }
    if (!result) {
        if (className) {
            
            NSArray* entities = [self entities];
            int i;
            for (i = [entities count]-1; i>=0; i--) {
                id entity = [entities objectAtIndex: i];
                if ([[entity managedObjectClassName] isEqualToString: className]) {
                    result = entity; 
                    [cache setObject: result forKey: className];
                    break;
                }
            }
        }
    }
    return result;
}

@end
