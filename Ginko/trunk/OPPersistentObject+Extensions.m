//
//  NSPersistentObjectContext+Extensions.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 02.08.05.
//  Copyright 2005 Dirk Theisen. All rights reserved.
//

#import "OPPersistentObject+Extensions.h"
#import "OPPersistentObjectContext.h"

@implementation OPPersistentObject (OPExtensions)

static volatile NSThread* mainThread = nil;

+ (void) initialize 
{
	if (!mainThread) {
		mainThread = [NSThread currentThread]; // expecting to be initialized in the main thread;
	}
}

+ (NSArray*) allObjects
/*" Returns all committed persistent object instances of the reciever class. "*/
{
	return [[[OPPersistentObjectContext defaultContext] objectEnumeratorForClass: self where: nil] allObjects];
}

- (BOOL) primitiveBoolForKey: (NSString*) key
{
	BOOL result = [[self primitiveValueForKey: key] boolValue];
	return result;
}

@end

@implementation OPPersistentObjectContext (OPExtensions)


+ (OPPersistentObjectContext*) threadContext
{
    NSManagedObjectContext *result;
    NSMutableDictionary* threadDict = [[NSThread currentThread] threadDictionary];
	
    if (mainThread!=[NSThread currentThread]) NSLog(@"Caution: Editing context called from outside main thread!");
    
    result = [threadDict objectForKey: @"OPDefaultManagedObjectContext"];
	
    if (!result) {
		return [self mainThreadContext]; // hack?
    }
    
    NSAssert (result != nil, @"+[NSManagedObject (Extensions) threadContext]: context returned should never be nil");
    return result;
}

+ (void) setMainThreadContext: (OPPersistentObjectContext*) aContext
{
    NSMutableDictionary* threadDict = [[NSThread currentThread] threadDictionary];
    if (aContext) {
        [threadDict setObject:aContext forKey: @"OPDefaultManagedObjectContext"];
    } else {
        [threadDict removeObjectForKey: @"OPDefaultManagedObjectContext"];
    }
    mainThread = [NSThread currentThread];
}


+ (OPPersistentObjectContext*) mainThreadContext
    /*" Use carefully. "*/
{
	NSParameterAssert(mainThread!=nil);
    NSDictionary* threadDict = [mainThread threadDictionary];
    OPPersistentObjectContext* result = [threadDict objectForKey:@"OPDefaultManagedObjectContext"];
    return result;
}



+ (OPPersistentObject*) objectWithURL: (NSURL*) url
{
	return [[self threadContext] objectWithURL: url];
}

@end
