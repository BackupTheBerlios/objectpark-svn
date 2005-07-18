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

+ (id) objectWithURIString: (NSString*) uri
/*" Returns the  object for the uri given in the default context. "*/
{
    return [[self threadContext] objectWithURI: [NSURL URLWithString: uri]];
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
