//
//  NSPersistentObjectContext+Extensions.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 02.08.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "OPPersistentObject+Extensions.h"
#import "OPPersistentObjectContext.h"

@implementation OPPersistentObject (Extensions)

+ (NSArray*) allObjects
{
	return [[[OPPersistentObjectContext defaultContext] objectEnumeratorForClass: self where: nil] allObjects];
}

- (BOOL) primitiveBoolForKey: (NSString*) key
{
	BOOL result = [[self primitiveValueForKey: key] boolValue];
	return result;
}


@end
