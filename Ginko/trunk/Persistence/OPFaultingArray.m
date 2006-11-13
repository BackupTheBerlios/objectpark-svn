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
#import <OPDebug/OPLog.h>
#include <search.h>


@interface OPFaultingArrayEnumerator : NSEnumerator {
	int eindex;
	OPFaultingArray* hostArray;
}

+ (id) enumeratorWithArray: (OPFaultingArray*) array;
@end

/*" OPFaultingArray is considered thread-safe!. "*/

@implementation OPFaultingArray

/* Macros for accessing the two fields in the array entries */

#define oidPtr(oindex) (OID*)(data+((oindex)*entrySize))

#define sortObjectPtr(oindex) (id*)(data+((oindex)*entrySize)+sizeof(OID))


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
		//OPDebugLog(OPPERSISTENCE, OPINFO, @"OPFaultingArray %@ created.", self);
    }
    return self;
}

- (id) initWithArray: (NSArray*) otherArray {
    if (self = [self init]) {
        NSEnumerator* e = [otherArray objectEnumerator];
        id element;

        while (element = [e nextObject]) {
            [self addObject: element];
        }
    }
    return self;
}

- (id)initWithArray:(NSArray *)otherArray andSortKey:(NSString *)aSortKey
{
    if (self = [self init]) 
	{
		[self setSortKey:aSortKey];
		
        NSEnumerator *enumerator = [otherArray objectEnumerator];
        id element;
		
        while (element = [enumerator nextObject]) 
		{
            [self addObject:element];
        }
    }
	
    return self;
}
													  
- (id) initWithObjects: (id) firstObject, ... {

	 if (self = [super init]) {
		 
		 va_list	ap;
		 id		object;
		 
		 va_start(ap, firstObject);
		 for (object = firstObject; object != nil; object = va_arg(ap, id)) {
			 [self addObject: object];
		 }
		 
		 va_end(ap);
	 }
	 return self;
}


- (id) initWithContentsOfFile: (NSString*) path {
    // There may be more efficient implementations.
    return [self initWithArray: [NSArray arrayWithContentsOfFile: path]];
}

- (id) initWithObjects: (id*) objects count: (unsigned) count {
    NSParameterAssert(NO);
    return nil;
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
		@synchronized(self) {
			NSAssert(count==0, @"You can only set a sort key for an empty array (for now).");
			[sortKey autorelease];
			sortKey   = [newSortKey retain];
			entrySize = sizeof(OID) + (sortKey ? sizeof(void*) : 0);
			data      = realloc(data, (capacity+3) * entrySize );
		}
	}
}


- (id) lastObject
{
	id result;
	@synchronized(self) {
		result = count ? [self objectAtIndex: count-1] : nil;
	}
	return result;
}

- (id) init
{
	return [self initWithCapacity: 10];
}

- (OID) oidAtIndex: (unsigned) index;
{
	OID result;
	@synchronized(self) {
		NSParameterAssert(index < count);
		result = *oidPtr(index);
	}
	return result;
}

- (OID) lastOid;
/*" Returns the last OID or NILOID, if the reciever is empty. "*/
{
	OID result;
	@synchronized(self) {
		result = count ? *oidPtr(count-1) : NILOID;
	}
	return result;
}


- (void) _growTo: (unsigned) newCapacity
// caller must syncronize!
{
	capacity=MAX( capacity*2+2, newCapacity );
    if ( data ) {
        data=realloc( data, (capacity+3)*entrySize );
    } else {
        data=malloc( (capacity+3) * entrySize );
		//memset(data, 0, (capacity+3) * entrySize); // nullify memory.
    }
}

- (void) removeObjectAtIndex: (unsigned) index
{
	if (index!=NSNotFound && count>0) {
		NSParameterAssert(index<count);
		//NSLog(@"Removing element %#u of %@", index, self);
		
		@synchronized(self) {
			if (sortKey) [*sortObjectPtr(index) release];
			// Test, if we need to move elements:
			if (index<count-1) {
				OID movedoid = *oidPtr(index+1); 
				
				memmove(oidPtr(index), oidPtr(index+1), ((count-index)-1) * entrySize);
				// Will there be an entry left?
				if (count>2) {
					NSAssert2(movedoid == *oidPtr(index), @"move did not work for index %d in %@", index, self);
				}
			}
			count--;
		}
		//NSLog(@"Removed element. Now %@.", self);
	}
#warning Implement array shrinking!
}

- (void) removeObject: (OPPersistentObject*) anObject
{
	@synchronized(self) {
		if (anObject) {
			
			unsigned index = [self indexOfObject: anObject];
			//if (index==NSNotFound) {
			//NSLog(@"Warning: Try to remove a nonexisting object %@.", anObject);
			//}
			[self removeObjectAtIndex: index];
		}
	}
}

- (void) removeLastObject
{
	@synchronized(self) {
		if (count) count--;
	}
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

- (OPPersistentObjectContext*) context
{
	return [OPPersistentObjectContext defaultContext];
}



- (id) sortObjectAtIndex: (unsigned) index
/*" Returns the attribute used for sorting for the object at the index given. Raises, if "*/
{
	NSParameterAssert(index < count);
	NSAssert(sortKey!=nil, @"Only allowed, with sortKey set.");
	id result = nil;
	OID oid;
	id* storedSortObjectPtr;
	@synchronized(self) {
		oid = *oidPtr(index);
		storedSortObjectPtr = sortObjectPtr(index);
	} // rest only works on local data

	// See, if there is an object registered with the context:
	OPPersistentObject* object = [[self context] objectRegisteredForOid: oid ofClass: elementClass];
	// Avoid firing a fault to access the sort attribute:
	if (object && ![object isFault]) {
		result = [object valueForKey: sortKey]; // what happens, if it returns nil?

		if (result != *storedSortObjectPtr) {
			// Update stored sortObject:
			
			if (![*storedSortObjectPtr isEqual: result]) 
				needsSorting = YES; // error?
			
			// Free the stored object if favor of the object's attribute:
			[*storedSortObjectPtr release];
			*storedSortObjectPtr = [result retain];
		}
	} else {
		// Fall back to cached sortObject:
		result = *storedSortObjectPtr;
	}
	
	return result;
}


static int compare_oids(const void* entry1, const void* entry2)
{
	// Compare OIDs:
	OID oid1 = *((OID*)entry1);
	OID oid2 = *((OID*)entry2);
	return oid1==oid2 ? 0 : oid1<oid2 ? -1 : 1; // can math lib do this?	
}


static int compare_sort_objects(const void* entry1, const void* entry2)
{
	// Compare sort objects (pointers located behind the OIDs):
	id obj1 = *((id*)(entry1+sizeof(OID)));
	id obj2 = *((id*)(entry2+sizeof(OID)));
	
	if (obj1==obj2) return 0;

	//NSCAssert(obj1!=nil && obj2!=nil, @"nil sort keys");
	if (obj1==nil) return -1;
	if (obj2==nil) return 1;
	
	return [obj1 compare: obj2];	
}

- (void) sort 
{
	if (needsSorting) {
		int err = mergesort(data, 
							count, 
							entrySize, 
							sortKey ? compare_sort_objects : compare_oids);
		
		NSAssert2(err==0, @"Sorting error in %@: %s", self, strerror(err));
		needsSorting = NO;
	}
}

static int compare_sort_object_with_entry(const void* sortObject, const void* entry)
{
	id obj1 = *((id*)sortObject);
	id obj2 = *((id*)(entry+sizeof(OID)));
	
	if (obj1==obj2) return 0;
	//NSCAssert(obj1!=nil && obj2!=nil, @"nil sort keys");

	if (obj1==nil) return -1;
	if (obj2==nil) return 1;
	return [obj1 compare: obj2];	
}

- (unsigned) indexOfObjectIdenticalTo: (OPPersistentObject*) anObject
{
	unsigned result = [self indexOfObject: anObject];
	if (result != NSNotFound) {
		if (anObject == [self objectAtIndex: result]) return result;
		NSLog(@"Warning - indexOfObjectIdenticalTo might have failed?");
	}
	return NSNotFound;
}


- (unsigned) linearSearchForOid: (OID) oid
{
	unsigned resultIndex = NSNotFound;
	if (oid) {
		// Search for oid:
		size_t elementCount = count; 
		char* result = lfind(&oid, data, &elementCount, entrySize, compare_oids);
		if (result) {
			resultIndex =  (result-data)/entrySize;
			NSAssert([self oidAtIndex: resultIndex] == oid, @"lfind failed");
		}	
	}
	return resultIndex;
}

- (BOOL) isReallySorted
// For debugging only!
{
	if (sortKey) {
		int i;
		
		for (i=0;i<count-1;i++) {
			NSAssert([[self sortObjectAtIndex: i] compare: [self sortObjectAtIndex: i+1]]<=0, @"faulted array not sorted!");
		}
	}
	return YES;
}

- (BOOL) containsObject: (OPPersistentObject*) anObject
{
	unsigned resultIndex;
	@synchronized(self) { // only needed because of debugging code
		resultIndex = [self indexOfObject: anObject];
		
		/*
		if (NSDebugEnabled) {
			unsigned lresultIndex = [self linearSearchForOid: [anObject currentOid]];
			if (lresultIndex != resultIndex) {
				[self isReallySorted];
				resultIndex = lresultIndex;
				unsigned resultIndex2 = [self indexOfObject: anObject]; // step into this!
			}
		}
		 */
	}
	return resultIndex != NSNotFound;
}


- (void) updateSortObjectForObject: (id) element 
{
	NSParameterAssert(sortKey!=nil);
	OID oid = [element oid];
	@synchronized(self) {
		unsigned objectIndex = [self linearSearchForOid: oid];
		if (objectIndex == NSNotFound) {
			NSLog(@"Warning: no sort object to update.");
			return;
		}
		[self removeObjectAtIndex: objectIndex];
		[self addObject: element];
	}
}


- (unsigned) indexOfFirstSortObjectEqualTo: (id) sortObject
/*" Returns the lowest index of an object with sort object equal to the sortObject given. Returns NSNotFound, if no such index exists. "*/
{
	NSAssert(sortKey, @"indexOfFirstSortObjectEqualTo requires a sort key to be set.");
	// Make sure, we are sorted:
	[self sort]; // already done above?
				 // Search for sortKey:
	char* result = bsearch(&sortObject, data, count, entrySize, compare_sort_object_with_entry);
	if (result) {
		// We found a matching sort-key.		
		
		unsigned resultIndex = (result-data)/entrySize;
		
		if (resultIndex>0) {
			// Walk backward until the sortKey no longer matches : 
			unsigned searchIndex = resultIndex-1;
			while (searchIndex >= 0 && [sortObject compare: *sortObjectPtr(searchIndex)]==0) {
				resultIndex = searchIndex;
				searchIndex--;
			}
		}
		return resultIndex;
	}
	return NSNotFound;
}

- (unsigned) indexOfObject: (OPPersistentObject*) anObject
	/*" Returns an index containing the anObject or NSNotFound. If anObject is contained multiple times, any of the occurrence-indexes is returned. This method is reasonably efficient with less than O(n) runnning time for the second call in a row. "*/
{
	unsigned resultIndex = NSNotFound;
	OID oid = [anObject currentOid]; // should be efficient
	
	// Without oid, the object cannot be in this array!
	if (oid) {
		@synchronized(self) {
			// Make sure, we are sorted:
			[self sort]; 
			
			if (sortKey) {
				
				if ([anObject isFault]) {
					// Firing a fault is probably more expensive than a linear search:				
					resultIndex = [self linearSearchForOid: oid];
					
				} else {
					id key = [anObject valueForKey: sortKey]; // may fire fault! avoid that!
					
					// Make sure, we are sorted:
					[self sort]; // already done above?
					// Search for sortKey:
					char* result = bsearch(&key, data, count, entrySize, compare_sort_object_with_entry);
					if (result) {
						// We found a matching sort-key.		
						
						resultIndex = (result-data)/entrySize;
						
						if (*((OID*)result) != oid) { // found using only bsearch on the keys
							
							unsigned searchIndex;
							
							// Walk backward until the sortKey no longer matches or oid found: 
							if (resultIndex) {
								searchIndex = resultIndex-1;
								while (searchIndex >= 0 && [key compare: *sortObjectPtr(searchIndex)]==0) {
									if (oid == *oidPtr(searchIndex)) {
										return searchIndex; // found
									}
									searchIndex--;
								}
							}
							// Walk forward until the sortKey no longer matches or oid found: 
							searchIndex = resultIndex+1;
							while (searchIndex<count) {
								id searchIndexKey = *sortObjectPtr(searchIndex);
								if ([key compare: searchIndexKey] != 0) 
									break;
								
								if (oid == *oidPtr(searchIndex)) return searchIndex; // found
								searchIndex++;
							}
							
							resultIndex = NSNotFound;
						}
					}
					
				}
			} else {
				
				// Make sure, we are sorted:
				[self sort]; 
				// Search for oid:
				char* result = bsearch(&oid, data, count, entrySize, compare_oids);
				if (result) {
					resultIndex =  (result-data)/entrySize;
				}
			}
		}
	}
	return resultIndex;
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
	@synchronized(self) {
		if (count+1 >= capacity) {
			[self _growTo: count+1];
		}
		
		*oidPtr(count) = oid;
		
		if (sortKey) {
			// Cache the sortObject:
			//NSLog(@"Adding sortObject: %@", sortObject);
			[sortObject retain];
			//NSLog(@"Adding Sortkey %@ at index: %d", sortObject, count);
			*sortObjectPtr(count) = sortObject;
		}
		count+=1;
		
		//if (sortKey) NSLog(@"xxx: %@", self);
		if (!needsSorting && count>1) {
			// No need to set unsorted flag, if we insert in a sorted manner:
			//needsSorting = [self compareObjectAtIndex: count-2 withObjectAtIndex: count-1] > 0; // optimization - be careful accessing other sort objects - they might not be upto-date
			needsSorting = YES; //[self compareObjectAtIndex: count-2 withObjectAtIndex: count-1] > 0; optimize later
		}
	}
}

- (void) addObject: (OPPersistentObject*) anObject
/*" Only objects of the same class can be added for now. "*/
{
	@synchronized(self) {
		if (!elementClass) {
			// Remember the element class - objects have to be uniform for now
			NSParameterAssert([anObject isKindOfClass: [OPPersistentObject class]]);
			elementClass = [anObject class]; // remember the element class
		}
		
		/*
		if (NSDebugEnabled && [self containsObject: anObject]) {
			NSLog(@"Warning: producing double entry '%@' in faulting array '%@'", anObject, self);
			NSBeep();
			[self containsObject: anObject];
		}
		 */
		
		NSParameterAssert([anObject class] == elementClass);
		
		[self addOid: [anObject oid] sortObject: sortKey ? [anObject valueForKey: sortKey] : nil];
	}
}



- (id) objectAtIndex: (unsigned) anIndex
/*" The result is autoreleased in the caller's thread. "*/
{
	OID oid;
	@synchronized(self) {
		NSParameterAssert(anIndex<count);
		[self sort];
		oid = *oidPtr(anIndex);
	}

	id result = [[self context] objectForOid: oid ofClass: elementClass];
	NSAssert1(result!=nil, @"Error! Object in FaultArray %@ no longer accessible!", self);
	return [[result retain] autorelease];
}

- (NSArray *)subarrayWithRange:(NSRange)range
{
	OPFaultingArray *result = [[[OPFaultingArray alloc] init] autorelease];
	[result setElementClass:elementClass];
	[result setSortKey:sortKey];
	
	int i;
	
	for (i = range.location; i < NSMaxRange(range); i++)
	{
		[result addOid:[self oidAtIndex:i] sortObject:[self sortObjectAtIndex:i]];
	}

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
			id value = [[self sortObjectAtIndex: i] description];
			[keys appendString: @", "];
			[keys appendString: value ? value : @"--nil--"];
		}
	}
	return [NSString stringWithFormat: @"<%@ with %d elements, sortkey: %@ %@>", [super description], count, sortKey, keys];
}

- (void) dealloc
{
	// Make sure, all sortObjects are released
	if (sortKey) {
		while (count>0) {
			// Remove last element till empty, which is efficient:
			[self removeObjectAtIndex: (count-1)];
		}
	}
	
	if (data) free(data);
	[super dealloc];
}


/*
- (id) autorelease
{
	return [super autorelease];
}
- (void) release
{
	[super release];
}
- (id) retain
{
	return [super retain];
}
*/

- (unsigned) count
{
	return count;
}

- (NSEnumerator*) objectEnumerator
{
	return [OPFaultingArrayEnumerator enumeratorWithArray: self];
}

/*
- (void) makeObjectsPerformSelector: (SEL) selector
{
	NSEnumerator* e = [self objectEnumerator];
	id entry;
	while (entry = [e nextObject]) {
		[entry performSelector: selector];
	}
}
*/

@end


@implementation OPFaultingArrayEnumerator

- (id) initWithArray: (OPFaultingArray*) array
{
	if (self = [super init]) {
		hostArray = [array retain];
	}
	return self;
}

+ (id) enumeratorWithArray: (OPFaultingArray*) array
{
	return [[((OPFaultingArrayEnumerator*)[self alloc]) initWithArray: array] autorelease];
}


- (id) nextObject
{	
	if ([hostArray count]>eindex) {
		return [[[hostArray objectAtIndex: eindex++] retain] autorelease];
	}
	[hostArray release]; hostArray = nil;
	return nil;
}

- (void) dealloc
{
	[hostArray release]; hostArray = nil;
	[super dealloc];
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
	[array addObject: @"50"];
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

//- (BOOL) findObject: (OPPersistentObject*) anObject index: (unsigned*) indexSearched
//{
//	
//	int i = 0;
//#warning linear oid search! replace by binary-search using sort keys!
//	if (NO && sortKey) {
//		/*
//		 optimization
//		// Expect the array to be sorted. Use sort key:
//		id searchSortObject = [anObject valueForKey: sortKey];
//		
//		int res = -1;
//		for (; res<=0 && i<count;i++) {
//			id otherSortObject = [self sortObjectAtIndex: i];
//			res = [searchSortObject compare: otherSortObject];
//			if (res == 0) {
//				OID oidFound = *oidAdr(i);
//				if (oidFound==[anObject oid]) {
//					*indexSearched = i;
//					return YES;
//				}
//			}
//		}
//*/
//	} else {
//		// Just compare oids:
//		OID oid = [anObject oid];
//		for (;i<count;i++) {
//			OID oidFound = *oidPtr(i);
//			if (oidFound==oid) {
//				*indexSearched = i;
//				return YES;
//			}
//			//if (oidFound>oid) break;
//		}
//	}	
//	*indexSearched = i;
//	return NO;
//}