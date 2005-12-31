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
/*" Objects of this class keeps track of n:m relationship changes. "*/

- (id) initWithAttributeDescriptions: (OPAttributeDescription*) firstAttr 
									: (OPAttributeDescription*) secondAttr
{
	if (self = [super init]) {
		
		NSParameterAssert([firstAttr joinTableName] != nil || [firstAttr joinTableName] != nil);
		
		firstAttribute   = [firstAttr retain];
		secondAttribute  = [secondAttr retain];
		addedRelations   = [[NSMutableSet alloc] init];
		removedRelations = [[NSMutableSet alloc] init];
	}
	return self;
}

- (OPAttributeDescription*) firstAttributeDescription
{
	return firstAttribute;
}

- (OPAttributeDescription*) secondAttributeDescription
{
	return secondAttribute;
}

- (NSString*) joinTableName
{
	return firstAttribute ? [firstAttribute joinTableName] : [secondAttribute joinTableName];
}

- (NSString*) firstColumnName 
{
	return firstAttribute ? [firstAttribute sourceColumnName] : [secondAttribute targetColumnName];
}

- (NSString*) secondColumnName 
{
	return firstAttribute ? [firstAttribute targetColumnName] : [secondAttribute sourceColumnName];
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
	if (secondAttribute && [relationName isEqualToString: secondAttribute->name]) {
		swap(sourceObject, targetObject);
	} else {
		NSParameterAssert(firstAttribute && [relationName isEqualToString: firstAttribute->name]);
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
	if (secondAttribute && [relationName isEqualToString: secondAttribute->name]) {
		swap(sourceObject, targetObject);
	} else {
		NSParameterAssert(firstAttribute && [relationName isEqualToString: firstAttribute->name]);
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
	if (secondAttribute && [relationName isEqualToString: secondAttribute->name]) {
		objectColumn = 1;
	} else {
		objectColumn = 0;
		NSParameterAssert(firstAttribute && [relationName isEqualToString: firstAttribute->name]);
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
			// Remove related object from array:
			[array removeObject: [relation objectAtIndex: 1-objectColumn]];
		}
	}
}

- (NSEnumerator*) removedRelationsEnumerator
	/*" Enumerates all OPObjectPair objects in no particular order. "*/
{
	return [removedRelations objectEnumerator];
}

- (unsigned) changeCount
{
	return [removedRelations count] + [addedRelations count];
}

- (void) reset
/*" Removes all relations recorded. "*/
{
	[addedRelations removeAllObjects];
	[removedRelations removeAllObjects];
}

- (void) dealloc 
{
	[firstAttribute release];
	[secondAttribute release];
	[addedRelations release];
	[removedRelations release];
	[super dealloc];
}


@end

