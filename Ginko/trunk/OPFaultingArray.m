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

- (void) setSortFunction: (int (*)(id, id)) compareFunction
{
	compare = compareFunction;
}



+ (id) array
{
	return [[[self alloc] init] autorelease];
}

- (id) initWithCapacity: (unsigned int) newCapacity
{
    if ( self = [super init] ) {
		capacity=newCapacity;
		count=0;
		data=malloc( (capacity+3) * sizeof(int) );
	}
    return self;
}

- (void) sortUsingSelector: (SEL) selector 
{
	if ([self count]>0) {
	// todo: implement!
	}
}

- (void) setSortKey: (NSString*) newSortKey
{
	[sortKey autorelease];
	sortKey = [newSortKey retain];
	[self sortUsingSelector: NSSelectorFromString(sortKey)];
}


- (id) init
{
	return [self initWithCapacity: 10];
}

-(OID) oidAtIndex: (unsigned) index;
{
	NSParameterAssert(index < count);
	return data[index];
}

- (void)_growTo: (unsigned) newCapacity
{
    capacity=capacity*2+2;
	capacity=MAX( capacity, newCapacity );
    if ( data ) {
        data=realloc( data, (capacity+3)*sizeof(OID) );
    } else {
        data=calloc( (capacity+3), sizeof(OID) );
    }
}

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
		memccpy(&(data[index+1]), &(data[index]),(count-index)-1, sizeof(OID));
	}
	data[index] = anOid;
}


- (unsigned) indexOfObject: (OPPersistentObject*) anObject
/*" Returns an index containing the anObject or NSNotFound. If anObject is contained multiple times, any of the occurrence-indexes is returned. "*/
{
	// linear search! replace by binary-search!
	if (compare) {
		int i;
		int res = -1;
		for (i=0; res<0 && i<count;i++) {
			res = compare([self objectAtIndex: i], anObject);
		}
		if (res == 0) return i;
	} else {
		OID oid = [anObject oid];
		int i;
		for (i=0;i<count;i++) {
			if ([self oidAtIndex: i]==oid) return i;
		}
	}
	return NSNotFound;
}

- (void) removeObject: (OPPersistentObject*) anObject
{
	unsigned index = [self indexOfObject: anObject];
	if (index!=NSNotFound) {
		memccpy(&(data[index]), &(data[index+1]),(count-index)-1, sizeof(OID));
		count--;
#warning Implement array shrinking!
	}
}


- (void) addOid: (OID) anOid
{
	unsigned indexToInsert = count;
	if (sortKey) {
		NSLog(@"Warning! Sorted insertion not implemented yet.");
	} // otherwise add at the end:
	[self insertOid: anOid atIndex: indexToInsert];
}

- (void) addObject: (OPPersistentObject*) anObject
{
	if (!elementClass) elementClass = [anObject class]; // remember the element class
	
	NSParameterAssert([anObject class] == elementClass);
	[self addOid: [anObject oid]];
}

- (id) objectAtIndex: (unsigned) anIndex
{
	OID oid = [self oidAtIndex: anIndex];
	// Should we store and retain a context?
	id result = [[OPPersistentObjectContext defaultContext] objectForOid: oid ofClass: elementClass];
	NSAssert1(result!=nil, @"Error! Object in FaultArray %@ no longer accessible!", self);
	return result;
}

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

- (void) dealloc
{
	if (data) {
		free(data);
	}
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