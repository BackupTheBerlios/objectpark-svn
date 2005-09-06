//
//  MPWIntArray.m
//  MPWFoundation
//
//  Created by Marcel Weiher on Sat Dec 27 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import "OPFaultingArray.h"
#import <Foundation/Foundation.h>
#import "OPPersistentObjectContext.h"
#import "OPPersistentObject.h"

@implementation OPFaultingArray


int compareOids(OID o1, OID o2)
{
	return o1==o2 ? 0 : (o1<o2 ? -1 : 1);
}

/*
- (void) setSortFunction: (int (*)(id, id)) compareFunction
{
	compare = compareFunction;
}
*/


#define oidAdr(oindex) (OID*)(data+(oindex*entrySize))

#define sortObjectAdr(oindex) (id*)(data+(oindex*entrySize)+sizeof(OID))

#define setSortObjectAtIndex(newValue, aindex) {id* oldValuePtr=sortObjectAdr(aindex); if (*oldValuePtr!=newValue) {[*oldValuePtr autorelease]; *oldValuePtr=[newValue retain];}}

+ (id) array
{
	return [[[self alloc] init] autorelease];
}

- (id) initWithCapacity: (unsigned) newCapacity
{
    if ( self = [super init] ) {
		capacity     = newCapacity;
		count        = 0;
		entrySize    = sizeof(OID);
		needsSorting = NO;
		data         = malloc( (capacity+3) * entrySize );
	}
    return self;
}

- (void) sort
{
	NSAssert(sortKey, @"Try to sort without a sortKey set.");
#warning todo: implement sorting! 
	NSLog(@"Should sort array: %@", self);	
}

- (void) setSortKey: (NSString*) newSortKey
/*" When calling this method, the receiver may not contain any elements. "*/
{
	if (newSortKey != sortKey) {
		NSAssert(count==0, @"You can only set a sort key for an empty array (for now).");
		[sortKey autorelease];
		sortKey   = [newSortKey retain];
		entrySize = sizeof(OID) + (sortKey ? sizeof(void*) : 0);
		data      = realloc(data, (capacity+3) * entrySize );
	}
}


- (id) init
{
	return [self initWithCapacity: 10];
}

-(OID) oidAtIndex: (unsigned) index;
{
	NSParameterAssert(index < count);
	return *oidAdr(index);
}

- (void)_growTo: (unsigned) newCapacity
{
    capacity=capacity*2+2;
	capacity=MAX( capacity, newCapacity );
    if ( data ) {
        data=realloc( data, (capacity+3)*entrySize );
    } else {
        data=calloc( (capacity+3), entrySize );
    }
}

/*
- (void) insertOid: (OID) anOid atIndex: (unsigned) index
{
	// needs testing!
	NSParameterAssert(index<=count);
	count++;
	if ( count >= capacity ) {
		[self _growTo: count];
	}	
	if ((count-index)-1>0) { 
		// Move up elements, freeing element at index:
		memccpy(&(data[index+1]), &(data[index]),(count-index)-1, entrySize);
	}
	data[index] = anOid;
}
*/

- (BOOL) findObject: (OPPersistentObject*) anObject index: (unsigned*) indexSearched
{
	if (needsSorting) [self sort];
	
	int i = 0;
#warning linear search! replace by binary-search!
	if (compare) {
		int res = -1;
		for (; res<0 && i<count;i++) {
			res = compare([self objectAtIndex: i], anObject, (OPFaultingArray*)self);
		}
		if (res == 0) {
			*indexSearched = i;
			return YES;
		}
	} else {
		OID oid = [anObject oid];
		for (;i<count;i++) {
			OID oidFound = *oidAdr(i);
			if (oidFound==oid) {
				*indexSearched = i;
				return YES;
			}
			if (oidFound>oid) break;
		}
	}	
	*indexSearched = i;
	return NO;
}


- (unsigned) indexOfObject: (OPPersistentObject*) anObject
/*" Returns an index containing the anObject or NSNotFound. If anObject is contained multiple times, any of the occurrence-indexes is returned. "*/
{
	unsigned result;
	
	if ([self findObject: anObject index: &result]) {
		return result;
	}
	
	return NSNotFound;
	

}

- (void) removeObjectAtIndex: (unsigned) index
{
	if (index!=NSNotFound) {
		if (sortKey) [*sortObjectAdr(index) release];
		memccpy(oidAdr(index), oidAdr(index+1),(count-index)-1, entrySize);
		count--;
#warning Implement array shrinking!
	}	
}

- (void) removeObject: (OPPersistentObject*) anObject
{
	[self removeObjectAtIndex: [self indexOfObject: anObject]];
}

/*
- (void) addOid: (OID) anOid
{
	unsigned indexToInsert = count;
	if (sortKey) {
		NSLog(@"Warning! Sorted insertion not implemented yet.");
	} // otherwise add at the end:
	[self insertOid: anOid atIndex: indexToInsert];
}
*/

//- (void) setSortObjectAtIndex: (unsigned) oindex


- (id) sortObjectAtIndex: (unsigned) index
/*" Returns the attribute used for sorting for the object at the index given. Raises, if "*/
{
	NSAssert(sortKey!=nil, @"Only allowed, with sortKey set.");
	id result = nil;
	// See, if there is an object registered with the context:
	OPPersistentObject* object = [[self context] objectRegisteredForOid: *oidAdr(index) ofClass: elementClass];
	if (object && ![object isFault]) {
		// Avoid firing a fault to access the sort attribute:
		result = [object valueForKey: sortKey]; // what happens, if it returns nil?
		setSortObjectAtIndex(result, index);
	} else {
		// fall back to cached sortObject:
		result = *sortObjectAdr(index);
	}
	
	return result;
}

- (void) addOid: (OID) oid sortObject: (id) sortObject
/*" The sortObject may be nil, if sortKey is nil. "*/
{	
	if (count+1 >= capacity) {
		[self _growTo: count+1];
	}
	
	*oidAdr(count) = oid;
	
	if (sortKey) {
		// Cache the sortObject:
		[sortObject retain];
		setSortObjectAtIndex(sortObject, count);
	}
	
	count+=1;
	needsSorting = (sortKey!=nil);	
}

- (void) addObject: (OPPersistentObject*) anObject
{
	if (!elementClass) 
		elementClass = [anObject class]; // remember the element class
	
	NSParameterAssert([anObject class] == elementClass);
	
	[self addOid: [anObject oid] sortObject: sortKey ? [anObject valueForKey: sortKey] : nil];
}

- (OPPersistentObjectContext*) context
{
	return [OPPersistentObjectContext defaultContext];
}

- (id) objectAtIndex: (unsigned) anIndex
{
	OID oid = *oidAdr(anIndex);
	// Should we store and retain a context?
	id result = [[self context] objectForOid: oid ofClass: elementClass];
	NSAssert1(result!=nil, @"Error! Object in FaultArray %@ no longer accessible!", self);
	return result;
}

/*
-(void) replaceOidAtIndex: (unsigned) anIndex
				  withOid: (OID) anOid
{
	NSParameterAssert( anIndex < count );
	data[anIndex] = anOid;
}


-(void) replaceObjectAtIndex: (unsigned) anIndex 
				  withObject: (OPPersistentObject*) anObject
{
	NSParameterAssert([anObject class] == elementClass);
	[self replaceOidAtIndex: anIndex withOid: [anObject oid]];
}
*/

- (void) dealloc
{
	// Make sure, all sortObjects are released
	if (sortKey) {
		while (count) [self removeObjectAtIndex: count-1];
	}
	
	if (data) free(data);
	[super dealloc];
}

- (unsigned) count
{
	return count;
}

@end


/*
@implementation OPFaultingArray (testing)

+(void) testArrayAccess
{
	id array=[self array];
	INTEXPECT( [array count], 0 ,@"count of empty array");
	[array addInteger:42];
	INTEXPECT( [array count],1 ,@"count after adding 1 element");
	INTEXPECT( [array integerAtIndex:0],42 ,@"value of element I put");
	[array addObject:@"50"];
	INTEXPECT( [array count],2 ,@"count after adding 2nd element");
	INTEXPECT( [array integerAtIndex:1],50 ,@"value of 2nd element I put");
}

+ testSelectors
{
	return [NSArray arrayWithObjects:
		@"testArrayAccess",
		nil];
}

@end
*/

/*
 - (void) addOids: (OID*) intArray count: (unsigned) numOidsToAdd
 {
	 unsigned newCount=count+numOidsToAdd;
	 if ( newCount >= capacity ) {
		 [self _growTo:newCount];
	 }
	 memcpy( data+count, intArray, numOidsToAdd * sizeof(OID));
	 count=newCount;
 }
 */