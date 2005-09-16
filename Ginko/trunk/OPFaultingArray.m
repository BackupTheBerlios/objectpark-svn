//
//  OPFaultingArray.m
//  OPPersistence
//
//  Created by Dirk Theisen  on Sat Dec 27 2004.
//  Copyright (c) 2003 Dirk Theisen. All rights reserved.
//

#import "OPFaultingArray.h"
#import <Foundation/Foundation.h>
#import "OPPersistentObjectContext.h"
#import "OPPersistentObject.h"

@implementation OPFaultingArray

/*" Warning: This class is not thread-save! "*/

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


#define oidPtr(oindex) (OID*)(data+(oindex*entrySize))

#define sortObjectPtr(oindex) (id*)(data+(oindex*entrySize)+sizeof(OID))

//#define setSortObjectAtIndex(newValue, aindex) {id* oldValuePtr=sortObjectAdr(aindex); if (*oldValuePtr!=newValue) {[*oldValuePtr autorelease]; *oldValuePtr=[newValue retain];}}

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
#warning todo: implement sorting! 
	NSLog(@"Should sort array: %@", self);	
}


- (void) setElementClass: (Class) eClass
/*" This is only necessary if the receiver was filled using addOid... methods. "*/
{
	NSParameterAssert(count==0);
	elementClass = eClass;
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
		//memset(data, 0, (capacity+3) * entrySize); // nullify memory.
	}
}


- (id) lastObject
{
	return count ? [self objectAtIndex: count-1] : nil;
}

- (id) init
{
	return [self initWithCapacity: 10];
}

-(OID) oidAtIndex: (unsigned) index;
{
	NSParameterAssert(index < count);
	return *oidPtr(index);
}

- (void)_growTo: (unsigned) newCapacity
{
	capacity=MAX( capacity*2+2, newCapacity );
    if ( data ) {
        data=realloc( data, (capacity+3)*entrySize );
    } else {
        data=malloc( (capacity+3) * entrySize );
		//memset(data, 0, (capacity+3) * entrySize); // nullify memory.
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
	
	int i = 0;
#warning linear oid search! replace by binary-search using sort keys!
	if (NO && sortKey) {
		/*
		 optimization
		// Expect the array to be sorted. Use sort key:
		id searchSortObject = [anObject valueForKey: sortKey];
		
		int res = -1;
		for (; res<=0 && i<count;i++) {
			id otherSortObject = [self sortObjectAtIndex: i];
			res = [searchSortObject compare: otherSortObject];
			if (res == 0) {
				OID oidFound = *oidAdr(i);
				if (oidFound==[anObject oid]) {
					*indexSearched = i;
					return YES;
				}
			}
		}
*/
	} else {
		// Just compare oids:
		OID oid = [anObject oid];
		for (;i<count;i++) {
			OID oidFound = *oidPtr(i);
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

- (BOOL) containsObject: (OPPersistentObject*) anObject
{
	return [self indexOfObject: anObject] != NSNotFound;
}

- (unsigned) indexOfObject: (OPPersistentObject*) anObject
/*" Returns an index containing the anObject or NSNotFound. If anObject is contained multiple times, any of the occurrence-indexes is returned. "*/
{
	unsigned result;	
	if (needsSorting) [self sort]; // does nothing, currently

	if ([self findObject: anObject index: &result]) {
		return result;
	}
	return NSNotFound;
}

- (void) removeObjectAtIndex: (unsigned) index
{
	if (index!=NSNotFound) {
		if (sortKey) [*sortObjectPtr(index) release];
		memccpy(oidPtr(index), oidPtr(index+1),(count-index)-1, entrySize);
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
/*
 
 void Sort(id self, int begin, int end) 
 {
	 int mid;  
	 if (begin == end)     
		 return; 
	 if (begin == end - 1) 
		 return;
	 mid = (begin + end) / 2;
	 Sort(self, begin, mid);
	 Sort(self, mid, end);
	 Merge(self, begin, mid, end); //Don't forget to get Merge()
 }
 
 
 */


- (id) sortObjectAtIndex: (unsigned) index
/*" Returns the attribute used for sorting for the object at the index given. Raises, if "*/
{
	NSParameterAssert(index < count);
	NSAssert(sortKey!=nil, @"Only allowed, with sortKey set.");
	id result = nil;
	// See, if there is an object registered with the context:
	OPPersistentObject* object = [[self context] objectRegisteredForOid: *oidPtr(index) ofClass: elementClass];
	// Avoid firing a fault to access the sort attribute:
	if (object && ![object isFault]) {
		result = [object valueForKey: sortKey]; // what happens, if it returns nil?
		id* storedSortObjectPtr = sortObjectPtr(index);
		if (result != *storedSortObjectPtr) {
			// Update stored sortObject:
			[*storedSortObjectPtr release];
			*storedSortObjectPtr = [result retain];
#warning Updating sortObjects may make array unsorted
		}
	} else {
		// fall back to cached sortObject:
		result = *sortObjectPtr(index);
	}
	
	return result;
}

/*" Compares the sort attribute (sort key or oid) of the objects at the specified indices. Warning: Equality may not mean they are the same objects, they just have equal sort attributes. "*/
- (int) compareObjectAtIndex: (unsigned) index1 
		   withObjectAtIndex: (unsigned) index2
{
	if (sortKey) {
		id obj1 = [self sortObjectAtIndex: index1];
		id obj2 = [self sortObjectAtIndex: index2];
		return [obj1 compare: obj2];
	} 
	// Compare OIDs:
	OID* oidp1 = oidPtr(index1);
	OID* oidp2 = oidPtr(index2);
	return *oidp1==*oidp2 ? 0 : oidp1<oidp2 ? -1 : 1; // can math lib do this?	
}


- (void) addOid: (OID) oid sortObject: (id) sortObject
/*" The sortObject may be nil, if sortKey is nil. "*/
{	
	NSParameterAssert(!sortObject || sortKey);
	if (count+1 >= capacity) {
		[self _growTo: count+1];
	}
	
	*oidPtr(count) = oid;
	
	if (sortKey) {
		// Cache the sortObject:
		[sortObject retain];
		//NSLog(@"Adding Sortkey %@ at index: %d", sortObject, count);
		*sortObjectPtr(count)=[sortObject retain];
	}
	
	
	//if (sortKey) NSLog(@"xxx: %@", self);
	if (sortKey!=nil && !needsSorting && count>0)
		needsSorting = ([[self sortObjectAtIndex: count-1] compare: sortObject] > 0);	// compare sortObject with last object!
	
	count+=1;
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
	OID oid = *oidPtr(anIndex);
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

- (NSString*) description
{
	// Keys are just for testing...
	NSMutableString* keys = [NSMutableString string];
	if (NO && sortKey) {
		int i;
		for (i=0; i<count;i++) {
			[keys appendString: @", "];
			[keys appendString: [[self sortObjectAtIndex: i] description]];
		}
	}
	return [NSString stringWithFormat: @"<%@ with %d elements, sortkey: %@ %@>", [super description], count, sortKey, keys];
}

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