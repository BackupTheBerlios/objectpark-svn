//
//  OPObjectRelationship.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 14.12.05.
//  Copyright 2005 The Objectpark Group. All rights reserved.
//

#import "OPObjectRelationship.h"
#import "OPObjectPair.h"
#import "OPFaultingArray.h"

#define swap(x, y) { void* tmp = x; x = y; y = tmp; }


@implementation OPObjectRelationship
/*" Objects of this class keeps track of n:m relatioship changes. "*/

- (id) initWithRelationshipNames: (NSString*) firstName : (NSString*) secondName
{
	if (self = [super init]) {
		
		firstRelationshipName  = [firstName retain];
		secondRelationshipName = [secondName retain];
		addedRelations = [[NSMutableSet alloc] init];
		removedRelations = [[NSMutableSet alloc] init];
	}
	return self;
}


- (NSEnumerator*) addedRelationsEnumerator
	/*" Enumerates all OPObjectRelation objects in no particular order. "*/
{
	return [addedRelations objectEnumerator];
}

- (void) addRelationNamed: (NSString*) relationName 
					 from: (OPPersistentObject*) sourceObject
					   to: (OPPersistentObject*) targetObject
{
	// Swap 1st, 2nd as needed:
	if ([relationName isEqualToString: secondRelationshipName]) {
		swap(sourceObject, targetObject);
	} else {
		NSParameterAssert([relationName isEqualToString: firstRelationshipName]);
	}
	OPObjectPair* newRelation = [[OPObjectPair alloc] initWithObjects: sourceObject : targetObject];
	[removedRelations removeObject: newRelation];
	[addedRelations addObject: newRelation];
	[newRelation release];
}

- (void) removeRelationNamed: (NSString*) relationName 
						from: (OPPersistentObject*) sourceObject
						  to: (OPPersistentObject*) targetObject
{
	// Swap 1st, 2nd as needed:
	if ([relationName isEqualToString: secondRelationshipName]) {
		swap(sourceObject, targetObject);
	} else {
		NSParameterAssert([relationName isEqualToString: firstRelationshipName]);
	}
	OPObjectPair* removedRelation = [[OPObjectPair alloc] initWithObjects: sourceObject : targetObject]; // Optimize by faking object with stack allocated struct.
	[removedRelations addObject: removedRelation];
	[addedRelations removeObject: removedRelation];
	[removedRelation release];
}

- (void) updateRelationshipNamed: (NSString*) relationName 
							from: (OPPersistentObject*) anObject 
						  values: (OPFaultingArray*) array
	/*" Updates the array containing the objects related to anObject using the removed and added relations, adding any mathching added realtions, deleting any removed relations. "*/
{
	NSParameterAssert(anObject != nil);
	NSParameterAssert(array != nil);
	NSParameterAssert(relationName != nil);
	// Determine which column to look for:
	// todo
	int objectColumn = -1;
	if ([relationName isEqualToString: secondRelationshipName]) {
		objectColumn = 1;
	} else {
		objectColumn = 0;
		NSParameterAssert([relationName isEqualToString: firstRelationshipName]);
	}
	
	NSAssert1(objectColumn>=0, @"Unable to determine source column for object %@.", anObject);
	NSEnumerator* e;
	OPObjectPair* relation;
	e = [addedRelations objectEnumerator];
	while (relation = [e nextObject]) {
		if ([relation objectAtIndex: objectColumn] == anObject) {
			// Add related object to array:
			[array addObject: [relation objectAtIndex: 1-objectColumn]];
		}
	}
	e = [removedRelations objectEnumerator];
	while (relation = [e nextObject]) {
		if ([relation objectAtIndex: objectColumn] == anObject) {
			// Add related object to array:
			[array removeObject: [relation objectAtIndex: 1-objectColumn]];
		}
	}
}

- (NSEnumerator*) removedRelationsEnumerator
	/*" Enumerates all OPObjectPair objects in no particular order. "*/
{
	return [removedRelations objectEnumerator];
}

- (void) dealloc 
{
	[firstRelationshipName release];
	[secondRelationshipName release];
	[addedRelations release];
	[removedRelations release];
	[super dealloc];
}


@end

