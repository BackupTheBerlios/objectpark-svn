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
#include <search.h>


@interface OPFaultingArrayEnumerator : NSEnumerator {
	int eindex;
	OPFaultingArray* hostArray;
}

+ (id) enumeratorWithArray: (OPFaultingArray*) array;
@end


@implementation OPFaultingArray

/* Macros for accessing the two fields in the array entries */

#define oidPtr(oindex) ((OID*)(data+((oindex)*entrySize)))

#define sortObjectPtr(oindex) (id*)(data+((oindex)*entrySize)+sizeof(OID))

- (BOOL) canPersist
{
	return NO;
}

- (OID) oid
/*" Returns the object id for the receiver or NILOID if the object has no context.
 Currently, the defaultContext is always used. "*/
{
	if (!selfOID) {
		@synchronized(self) {
			// Create oid on demand, this means that this is now becoming persistent.
			// Persistent objects unarchived are explicitly given an oid:
			
			OPPersistentObjectContext* context = [self context];
			if (context) {
				[context insertObject: self];
			}
		}
	}
	return selfOID;
}

- (OID) currentOID
{
	return selfOID;
}

- (void) setOID: (OID) theOid
/*" Registers the receiver with the context, if neccessary. "*/
{
	@synchronized(self) {
		if (selfOID != theOid) {
			NSAssert(selfOID==0, @"Object ids can be set only once per instance.");
			selfOID = theOid;
			OPPersistentObjectContext* c = [self context];
			[c registerObject: self];
		}
	}
}
- (NSUInteger) hash
{
	return (NSUInteger)(LIDFromOID([self oid]) % NSUIntegerMax);
}

- (BOOL) isEqual: (id) other
{
	if (self == other) return YES;
	if (![other respondsToSelector: @selector(oid)]) {
		return NO;
	}
	
	return [self oid] == [other oid];
}


- (OPPersistentObjectContext*) context
/*" Returns the context for the receiver. Currently, always returns the default context. "*/
{
    return [OPPersistentObjectContext defaultContext]; // simplistic implementation; prepared for multiple contexts.
}

+ (id) array
{
	return [[[self alloc] init] autorelease];
}

- (Class) classForCoder
{
	// SuperClass did override this.
	return [self class];
}

#define entrySize sizeof(OID)

- (id) initWithCapacity: (NSUInteger) newCapacity;
{
    if ( self = [super init] ) {
		capacity     = MAX(3,newCapacity);
		count        = 0;
		data         = malloc( capacity * entrySize );
    }
    return self;
}

- (id) initWithArray: (NSArray*) otherArray 
{
    if (self = [self init]) {
		// should be optimized for the case that otherArray is a faulting array
        NSEnumerator* e = [otherArray objectEnumerator];
        id element;
		
        while (element = [e nextObject]) {
            [self addObject: element];
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

- (id) copyWithZone: (NSZone*) zone
/*" Returns an immutable instance of NSArray. "*/
{
	NSLog(@"Warning! %@ copied to immutable", self);
	return [[NSArray allocWithZone: zone] initWithArray: self];
}

- (id) mutableCopyWithZone: (NSZone*) zone
{
	NSLog(@"Warning! %@ copied mutable", self);
	return [[[self class] allocWithZone: zone] initWithArray: self];
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

- (OID) oidAtIndex: (NSUInteger) index;
{
	OID result;
	@synchronized(self) {
		NSParameterAssert(index < count);
		result = *oidPtr(index);
	}
	return result;
}

- (OID) lastOID;
/*" Returns the last OID or NILOID, if the reciever is empty. "*/
{
	OID result;
	@synchronized(self) {
		result = count ? *oidPtr(count-1) : NILOID;
	}
	return result;
}

- (void) didChange
/*" Notifies the context of a change so it can update on the persistent store. "*/
{
	[[self context] didChangeObject: self];
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
		[self didChange];
		//NSLog(@"Removed element. Now %@.", self);
	}
#warning Implement array shrinking!
}

//- (void) removeObject: (OPPersistentObject*) anObject
//{
//	@synchronized(self) {
//		if (anObject) {
//			
//			unsigned index = [self indexOfObject: anObject];
//			//if (index==NSNotFound) {
//			//NSLog(@"Warning: Try to remove a nonexisting object %@.", anObject);
//			//}
//			[self removeObjectAtIndex: index];
//		}
//	}
//}

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


static int compare_oids(const void* entry1, const void* entry2)
{
	// Compare OIDs:
	OID oid1 = *((OID*)entry1);
	OID oid2 = *((OID*)entry2);
	return oid1==oid2 ? 0 : oid1<oid2 ? -1 : 1; // can math lib do this?	
}


- (NSUInteger) indexOfOID: (OID) oid
{
	NSUInteger resultIndex = NSNotFound;
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

//- (BOOL) containsObject: (OPPersistentObject*) anObject
//{
//	unsigned resultIndex;
//	@synchronized(self) { // only needed because of debugging code
//		resultIndex = [self indexOfObject: anObject];
//		
//		/*
//		if (NSDebugEnabled) {
//			unsigned lresultIndex = [self linearSearchForOid: [anObject currentOid]];
//			if (lresultIndex != resultIndex) {
//				[self isReallySorted];
//				resultIndex = lresultIndex;
//				unsigned resultIndex2 = [self indexOfObject: anObject]; // step into this!
//			}
//		}
//		 */
//	}
//	return resultIndex != NSNotFound;
//}

- (NSUInteger) indexOfObject: (id) anObject
	/*" Returns an index containing the anObject or NSNotFound. If anObject is contained multiple times, any of the occurrence-indexes is returned. Optentially much slower than indexOfObjectIdenticalTo: due to faulting. "*/
{
	if (! [anObject isKindOfClass: [OPPersistentObject class]]) return NSNotFound;
	NSUInteger result = [self indexOfOID: [anObject currentOID]];
	if (result == NSNotFound) {
		result = [super indexOfObject: anObject]; // compares each element with - isEqual, faulting each.
	}
	return result;
}


- (NSUInteger) indexOfObjectIdenticalTo: (OPPersistentObject*) anObject
{
	if (! [anObject isKindOfClass: [OPPersistentObject class]]) return NSNotFound;
	return [self indexOfOID: [anObject currentOID]];
}


- (void) addOID: (OID) oid
{	
	@synchronized(self) {
		if (count+1 >= capacity) {
			[self _growTo: count+1];
		}
		
		*oidPtr(count) = oid;
		
		count+=1;
		
		[self didChange];
	}
}

- (void) addObject: (id) anObject
/*" Only objects of the same class can be added for now. "*/
{
	[self addOID: [anObject oid]];
}


- (id) objectAtIndex: (NSUInteger) anIndex
/*" The result is autoreleased in the caller's thread. "*/
{
	id result = nil;
	@synchronized(self) {
		if (anIndex  >= count) {
			NSBeep();
		}
		NSParameterAssert(anIndex<count);
		OID oid = *oidPtr(anIndex);
		OPPersistentObjectContext* context = [self context]; // todo - obtain context from either coder or inserted objects
		result = [context objectForOID: oid];
		if (!result)
			result = [context objectForOID: oid];
		if (result == nil) {
			//NSAssert1(result!=nil, @"Error! Object in FaultArray %016llx no longer accessible!", self);
		}
		[[result retain] autorelease];
	}
	return result;
}

- (NSArray*) subarrayWithRange: (NSRange) range
{
	OPFaultingArray* result = [[[OPFaultingArray alloc] init] autorelease];
	
	int i;
	
	for (i = range.location; i < NSMaxRange(range); i++) {
		[result addOID: [self oidAtIndex: i]];
	}

	return result;
}


- (void) replaceOIDAtIndex: (NSUInteger) anIndex
				   withOID: (OID) anOid
{
	NSParameterAssert( anIndex < count );
	*oidPtr(anIndex) = anOid;
	[self didChange];
}


- (void) replaceObjectAtIndex: (NSUInteger) anIndex 
				   withObject: (id) anObject
{
	[self replaceOIDAtIndex: anIndex withOID: [anObject oid]];
}


- (void) insertObject: (id) object atIndex: (NSUInteger) anIndex
{
	NSParameterAssert(object != nil);
	NSParameterAssert(anIndex <= count);
	@synchronized(self) {
		if (count+1 >= capacity) {
			[self _growTo: count+1];
		}
		
		memmove(oidPtr(anIndex+1), oidPtr(anIndex), (count-anIndex) * entrySize);
		*oidPtr(anIndex) = [object oid];
		count+=1;
	}
	[self didChange];
}


- (BOOL) hasUnsavedChanges
{
	return [[[self context] changedObjects] containsObject: self];
}

- (NSString*) description
{
	// Keys are just for testing...
	return [NSString stringWithFormat: @"<%@ with %d elements>", [super description], count];
}

- (id) initWithCoder: (NSCoder*) coder
{
	unsigned i = 0;
	OID oid;
	count = 0;
	do {
		NSString* key = [[NSString alloc] initWithFormat: @"OP#%u", i];
		oid = [coder decodeOIDForKey: key];
		if (oid) [self addOID: oid];
		[key release];
		i++;
	} while (oid);
	return self;
}

- (void) encodeWithCoder: (NSCoder*) coder
{
	int i;
	for (i = 0; i<count; i++) {
		NSString* key = [[NSString alloc] initWithFormat: @"OP#%u", i];
		[coder encodeOID: *oidPtr(i) forKey: key];
		[key release];
	}
}

- (void) addObserver:(NSObject*) observer toObjectsAtIndexes: (NSIndexSet*) indexes forKeyPath: (NSString*) keyPath options:(NSKeyValueObservingOptions) options context: (void*) context
{
	NSLog(@"Warning: addObserver:toObjectsAtIndexes... called on %@", self);
	[super addObserver: observer toObjectsAtIndexes: indexes forKeyPath: keyPath options: options context: context];	
}
- (void) removeObserver: (NSObject*) observer fromObjectsAtIndexes: (NSIndexSet*) indexes forKeyPath: (NSString*) keyPath
{
	NSLog(@"Warning: removeObserver:fromObjectsAtIndexes:forKeyPath called on %@", self);
	[super removeObserver: observer fromObjectsAtIndexes: indexes forKeyPath: keyPath];
}

- (NSUInteger) indexOfObjectIdenticalTo: (id) anObject inRange: (NSRange) range
{
	NSUInteger result = NSNotFound;
	if ([anObject respondsToSelector: @selector(oid)]) {
		
		OID oid = [anObject currentOID];
		if (oid) {
			NSParameterAssert(NSMaxRange(range) < count);
			for (NSUInteger i=range.location; i<NSMaxRange(range); i++) {
				OID elementOID = *oidPtr(i);
				if (elementOID == oid) return i;
			}			
		}	
	}
	return result;
}


- (void) dealloc
{	
	if (data) free(data);
	[super dealloc];
}


- (unsigned) count
{
	return count;
}

- (NSEnumerator*) objectEnumerator
{
	return [OPFaultingArrayEnumerator enumeratorWithArray: self];
}


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


@implementation NSArray (OPPersistence) 

- (BOOL) containsObjectIdenticalTo: (id) object
{
	return [self indexOfObjectIdenticalTo: object] != NSNotFound;
}

@end

//@implementation NSMutableArray (CocotronTest)
//
//
//-(void)removeObjectsFromIndices2: (unsigned *)indices
//					  numIndices: (unsigned)count {
//	int i;
//	
//	for(i=0;i<count;i++)
//		[self removeObjectAtIndex:indices[i]];
//}
//
//static int _nsmutablearraycompareindices(const void * index1, const void * index2)
//{
//	return index1 < index2 ? -1 : index1 == index2 ? 0 : 1;
//}
//
//static int _nsmutablearraycompareindices(const void* v1, const void* v2) 
//{
//	int i1 = (*(int*)v1);
//	int i2 = (*(int*)v2);
//	int result = i1 == i2 ? 0 : (i1<i2 ? -1 : 1);
//	return result;
//}
//
//-(void)removeObjectsFromIndices3: (unsigned *)indices
//					  numIndices: (unsigned) indexCount 
//{
//	if (count) {
//		unsigned sortedIndices[count]; 
//		memcpy(sortedIndices, indices, sizeof(unsigned)*count);
//		mergesort(sortedIndices, sizeof(unsigned), count, &_nsmutablearraycompareindices);
//		
//		
//		unsigned released = NSNotFound;
//		unsigned i, gap = 0;
//		unsigned imax = [self count];
//		for(i=sortedIndices[0]; i+gap<imax; i++) {
//			if (i == sortedIndices[gap]) {
//				gap += 1;
//				
//				[_objects[i] release];
//				released = i;
//			}
//			_objects[i] = _objects[i+gap];
//		}
//	}
//	
//	
//	unsigned lastIndex = NSNotFound;
//	for(i=count-1;i>=0;i--) {
//		unsigned index = sortedIndices[i];
//		if (index!=lastIndex) {
//			[self removeObjectAtIndex: index];
//		}
//		lastIndex = index;
//	}	
//}
//
//
//-(void) removeObjectsFromIndices: (unsigned*) indices
//					 numIndices: (unsigned) indexCount 
//{
//	if (count) {
//		unsigned sortedIndices[count]; 
//		memcpy(sortedIndices, indices, sizeof(unsigned)*count);
//		mergesort(sortedIndices, sizeof(unsigned), count, &_nsmutablearraycompareindices);
//		
//		unsigned lastIndex = NSNotFound;
//		int i;
//		for(i=count-1;i>=0;i--) {
//			unsigned index = sortedIndices[i];
//			if (index!=lastIndex) {
//				[self removeObjectAtIndex: index];
//			}
//			lastIndex = index;
//		}	
//	}
//}
//
//@end

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

//- (void) setParent: (OPPersistentObject*) theParent
//{
//	if (parent != theParent) {
//		NSParameterAssert(parent == nil);
//		parent = theParent;
//	}
//}
//
//- (OPPersistentObject*) parent
//{
//	NSAssert1(parent!=nil, @"Parent not set in %@", self);
//	return parent;
//}
