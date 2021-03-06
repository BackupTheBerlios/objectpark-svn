//
//  NSPersistentObjectContext+Extensions.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 02.08.05.
//  Copyright 2005 Dirk Theisen. All rights reserved.
//

#import "OPPersistentObject+Extensions.h"
#import "OPPersistentObjectContext.h"
#import "GIApplication.h"

@implementation OPPersistentObject (OPExtensions)

static volatile NSThread* mainThread = nil;

+ (void) initialize 
{
	if (!mainThread) {
		mainThread = [NSThread currentThread]; // expecting to be initialized in the main thread;
	}
}

+ (NSArray*) allObjects
/*" Returns all committed persistent object instances of the reciever class in their current (transient) 
	state. "*/
{
	return [[OPPersistentObjectContext defaultContext] allObjectsOfClass: self];
}

- (BOOL) primitiveBoolForKey: (NSString*) key
{
	BOOL result = [[self primitiveValueForKey: key] boolValue];
	return result;
}

- (void) setPrimitiveBool: (BOOL) yesno forKey: (NSString*) key 
{
	[self setValue: yesno ? yesNumber : nil forKey: key];
}

@end

@implementation OPPersistentObjectContext (OPExtensions)


+ (OPPersistentObjectContext*) threadContext
{
	return [self defaultContext];
/*
	
    OPPersistentObjectContext *result;
    NSMutableDictionary* threadDict = [[NSThread currentThread] threadDictionary];
	
    if (mainThread!=[NSThread currentThread]) NSLog(@"Caution: Editing context called from outside main thread!");
    
    result = [threadDict objectForKey: @"OPDefaultManagedObjectContext"];
	
    if (!result) {
		return [self mainThreadContext]; // hack?
    }
    
    NSAssert (result != nil, @"+[OPManagedObject (Extensions) threadContext]: context returned should never be nil");
    return result;
 */
}

+ (void) setMainThreadContext: (OPPersistentObjectContext*) aContext
{
	/*
    NSMutableDictionary* threadDict = [[NSThread currentThread] threadDictionary];
    if (aContext) {
        [threadDict setObject: aContext forKey: @"OPDefaultManagedObjectContext"];
    } else {
        [threadDict removeObjectForKey: @"OPDefaultManagedObjectContext"];
    }
    mainThread = [NSThread currentThread];
	 */
}


+ (OPPersistentObjectContext*) mainThreadContext
    /*" Use carefully. "*/
{
	return [self defaultContext];
	/*
	NSParameterAssert(mainThread!=nil);
    NSDictionary* threadDict = [mainThread threadDictionary];
    OPPersistentObjectContext* result = [threadDict objectForKey: @"OPDefaultManagedObjectContext"];
    return result;
	 */
}



+ (id) objectWithURLString: (NSString*) url resolve: (BOOL) resolve
/*" Pass YES to resolve to check with the dabase for object existence. "*/
{
	id result = [[self threadContext] objectWithURLString: url resolve: resolve];
	return result;
}


@end

@implementation NSError (OPExtensions)

+ (id) errorWithDomain: (NSString*) domain description: (NSString*) description
{
	NSString* ldescription = NSLocalizedString(description, @"");
	NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys: ldescription, NSLocalizedDescriptionKey, nil, nil];
	return [self errorWithDomain: domain code: 0 userInfo: userInfo];
}


@end
