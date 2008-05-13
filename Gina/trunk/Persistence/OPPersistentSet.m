//
//  OPPersistentSet.m
//  Gina
//
//  Created by Dirk Theisen on 09.05.08.
//  Copyright 2008 Objectpark;;Software GbR. All rights reserved.
//

#import "OPPersistentSet.h"
#import "OPPersistentObjectContext.h"

#define InvalidOID 1

// http://www.sieglin.de/arne/primzahlen.html

static NSUInteger prims[] = {3,5,7,11,17,23,29,37,43,53,113,193,271,359,443,541,619,719,821,911,1013,1097,1213,1429,1511,1609,1721,1831,1949,2053,2143,2273,2377,2473,2617,2707,2801,2917,3041,3181,3301,3391,3527,3617,3727,3851,3947,4079,4211,4297,4447,4561,4673,4799,4937,5023,5167,5297,5419,5521,5653,5779,5867,6029,6133,6263,6359,6491,6637,6761,6869,6983,7121,7243,7411,7529,7621,7741,7879,8017,8161,8273,8419,8543,8677,8779,8893,9029,9161,9283,9413,9511,9649,9781,9887,10061,10567,11383,11503,12049,12197,12323,12451,12553,12671,12821,12953,13751,13879,14011,14957,15121,15259,15359,16007,16447,16603,16729,16889,17551,17683,17839,17971,18097,18223,18341,18461,18637,18793,18979,19141,19273,19423,19507,19687,19813,19961,20071,20183,20347,20929,21589,21737,21859,22409,22567,22699,22817,22993,23081,23813,23917,24061,24169,24359,24499,24677,25127,25261,25411,25579,25693,25847,25981,26821,26951,27077,27259,27431,27583,27743,27827,27983,28111,28297,28447,29131,29873,30059,30931,31079,31193,31321,31511,31649,31793,31991,32117,32257,32371,32503,32621,32789,32939,33053,33199,33349,33493,33613,33751,33871,34039,34217,34337,34487,34613,34757,34913,35083,35227,36137,36299,36469,36587,36721,36857,36979,37139,37309,37447,37567,37693,37879,38047,38821,38959,39113,39233,39373,39541,39709,39841,39983,40813,40933,41081,41213,41357,42061,42727,42859,43013,44017,45053,46021,46171,46309,46477,47699,47819,47969,48157,49043,50069,5103,52027,53117,54037,54973,55117,56039,57041,58901,59021,60083,62137,63691,64007,65033,66067,67049,68903,69941,70111,71147,72161,73063,74099,75011,75181,76099,77093,78301,79153,80077,81001,82037,83009,84017,85121,86137,87103,88211,89057,90071,91097,92221,93083,94049,95003,96043,97021,97213,99991,120181,150151,4200003,250049,304279,350237,400109,450001,504187,550553,600361,657299,706669,752821,801631,859093,941509,999983};

@interface OPPSetEnumerator: NSEnumerator {
	OPPersistentSet* set;
	NSUInteger entryIndex;
}

- (id) initWithSet: (OPPersistentSet*) aSet;

@end

@implementation OPPersistentSet

- (OPPersistentObjectContext*) context
{
	return [OPPersistentObjectContext defaultContext];
}

- (NSUInteger) count
{
	return count;
}

- (float) usageFactor
{
	return (float) usedEntryCount / (float) entryCount;
}

- (void) removeAllObjects
{
	if (entries) free(entries);
	
	entries        = NULL;
	count          = 0;
	entryCount     = 0;
	usedEntryCount = 0;
}

- (void) dealloc
{
	[self removeAllObjects];
	[super dealloc];	
}


- (NSUInteger) entryIndexForObject: (NSObject<OPPersisting>*) object 
							   oid: (OID) objectOID
							  hash: (NSUInteger) objectHash
						returnFree: (BOOL) returnFree
/*" Returns an index in the entries array or NSNotFound if the object given is not contained (returnFree==NO) or already contained (returnFree=YES). For returnFree=YES the first index suitable for insertion is returned. object, objectOID and objectHash must match. object may be nil if objectOID and objectHash are given. "*/
{
	NSUInteger   result;
	OPHashEntry* entry;
	NSUInteger   step = 0;
	
	if (!entries) return NSNotFound;
	
	while ((entry = entries + (result = ((objectHash + step * (1+objectHash % (entryCount-2))) % entryCount)))->oid) {
		if (returnFree) {
			entry->oid;
			if (entry->oid == InvalidOID) {
				// while looking for a free spot, found a deleted entry
				return result;
			}
		} else {
			if (entry->oid != InvalidOID) {
				// We are looking for a matching entry
				if (entry->hash == objectHash) {
					if (entry->oid == objectOID) 
						return result;
					// Found equal hash values, but different oids - need to ask the object:
					id entryObject = [self.context objectForOID: (entry->oid)]; // potentially slow
					if (! entryObject) {
						NSLog(@"Warning - dangling oid reference in persistent set.");
					}
					if (! object) {
						object = [self.context objectForOID: objectOID];
					}
					if ([entryObject isEqual: object]) {
						return result;
					}
				}
			}
		}
		
		step += 1;
	}
	// No entry found, result points to an empty entry
	if (returnFree) {
		return result;
	}
	
	return NSNotFound;
}

- (void) rebuildWithMinCapacity: (NSUInteger) minCapacity
{
	NSUInteger    oldCount      = count;
	NSUInteger    oldEntryCount = entryCount;
	OPHashEntry*  oldEntries    = entries;
	
	for (int i=0; i<sizeof(prims); i++) {
		entryCount = prims[i];
		if (entryCount > 2 * minCapacity) {
			break;
		}
	}
	if (entryCount == oldEntryCount) return; // No better suitable prime number as table size found - do nothing
	
	entries        = calloc(entryCount, sizeof(OPHashEntry));
	count          = 0;
	usedEntryCount = 0;
	
	NSLog(@"Resizing persistent set to hold max %u entries (%u bytes each).", entryCount, sizeof(OPHashEntry));
	// copy over old entries by adding them:
	for (int i = 0; i < oldEntryCount; i++) {
		OPHashEntry* oldEntry = oldEntries + i;
		if (oldEntry->oid > 1) {
			NSUInteger eIndex = [self entryIndexForObject: nil
													  oid: oldEntry->oid
													 hash: oldEntry->hash
											   returnFree: YES];
			NSAssert(eIndex != NSNotFound, @"No free hash entry found during hash rebuild in OPPersistentSet.");
			usedEntryCount++;
			count++;
			// copy over entry
			entries[eIndex] = *oldEntry;
			
		}
	}
	NSAssert(count == oldCount, @"Count not same before and after hash rebuild.");
	if (oldEntries) free(oldEntries);
}


- (id) initWithObjects: (id*) objects count: (NSUInteger) ocount
{
	if (self = [super init]) {
		[self rebuildWithMinCapacity: ocount];
		for (int i=0; i<ocount; i++) {
			[self addObject: objects[i]];
		}
	}
	return self;
}


//- (OID) oidMember: (OID) queryOID hash: (NSUInteger) queryHash
/*" Return, the oid of an object contained in the receiver and equal to the object referenced by queryOID as determined by -hash and isEqual. "*/

- (id) member: (id) object
{
	NSUInteger bIndex = [self entryIndexForObject: object 
											  oid: [object oid]
											 hash: [object hash]
									   returnFree: NO];
	if (bIndex == NSNotFound) return nil;
	OID resultOid = entries[bIndex].oid;
	id result = [self.context objectForOID: resultOid];
	return [object isEqual: result] ? result : nil;
}


- (void) addObjectWithOID: (OID) oid hash: (NSUInteger) hash
/*" This low level method assumes enough room in entries table. "*/
{
	NSUInteger eIndex = [self entryIndexForObject: nil 
											  oid: oid
											 hash: hash
									   returnFree: YES];
	NSAssert(eIndex != NSNotFound, @"No room found in hash table to new entry.");
	OPHashEntry* entry = entries + eIndex;
	NSAssert(entry->oid <= InvalidOID, @"entry found for insertion not free.");
	
	if (entry->oid == NILOID) usedEntryCount++;
	entry->oid  = oid;
	entry->hash = hash;
	count++;
}
		
- (void) addObject: (id) object
{	
	if (entryCount <= usedEntryCount) {
		NSLog(@"Expanding persistent set...");
		[self rebuildWithMinCapacity: count];
	}
	
	NSUInteger eIndex = [self entryIndexForObject: object 
											  oid: [object oid]
											 hash: [object hash]
									   returnFree: YES];
	
	NSAssert2(eIndex != NSNotFound, @"Unable to find room for object %@ in set %@", object, self);
	
	OPHashEntry* entry = entries + eIndex;
	NSAssert(entry->oid <= InvalidOID, @"entry found for insertion not free.");
	
	if (entry->oid == NILOID) usedEntryCount++;
	entry->oid  = [object oid];
	entry->hash = [object hash];
	count++;
	[[object retain] autorelease]; // docu says we should retain, but we don't want to.
}

- (void) removeObject:  (id) object
{
	// Mark entry for object as invalid:
	NSUInteger bIndex = [self entryIndexForObject: object 
											  oid: [object oid]
											 hash: [object hash]
									   returnFree: NO];
	if (bIndex != NSNotFound) {
		NSAssert(entries[bIndex].oid != NILOID, @"entry found for insertion not free.");
		entries[bIndex].oid = InvalidOID;
		count--;
	}
	
	if (count < entryCount/4) {
		NSLog(@"Shrinking persistent set (from table size %u)...", entryCount);
		[self rebuildWithMinCapacity: count];
	}	
}

- (NSString*) description
{
	return [NSString stringWithFormat: @"%@, %00.00f%% used", [super description], self.usageFactor*100];
}

- (NSEnumerator*) objectEnumerator
{
	return [[[OPPSetEnumerator alloc] initWithSet: self] autorelease];
}

- (id) nextObjectWithEntryIndex: (NSUInteger*) entryIndex
{
	while (*entryIndex < entryCount) {
		OID oid = entries[*entryIndex].oid;
		(*entryIndex)++;

		if (oid > InvalidOID) {
			return [self.context objectForOID: oid];
		}
	}
	return nil;
}

- (id) initWithCoder: (NSCoder*) coder
{
	NSUInteger entryNo = [coder decodeInt32ForKey: @"count"];
	[self rebuildWithMinCapacity: entryNo];
	NSData* table = [coder decodeObjectForKey: @"tableData"];
	const char* cursor = [table bytes];
	while (entryNo--) {
		uint32 hash = *((uint32*)cursor); cursor+=sizeof(uint32);
		OID    oid  = *((OID*)cursor); cursor+=sizeof(OID);
		[self addObjectWithOID: oid hash: hash];
	}
	return self;
}


- (void) encodeWithCoder: (NSCoder*) coder
{
	[coder encodeInt32: count forKey: @"count"];
	NSMutableData* tableData = [NSMutableData data];
	for (int i = 0; i<entryCount; i++) {
		OPHashEntry* entry = entries+i;
		if (entry->oid > InvalidOID) {
			[tableData appendBytes: &entry->hash length: sizeof(uint32)];
			[tableData appendBytes: &entry->oid  length: sizeof(OID)];
		}
	}
	[coder encodeObject: tableData forKey: @"tableData"];
}

@end


@implementation OPPSetEnumerator

- (id) initWithSet: (OPPersistentSet*) aSet
{
	if (self = [super init]) {
		set = [aSet retain];
	}
	return self;
}

- (void) dealloc
{
	[set release];
	[super dealloc];
}

- (id) nextObject
{
	return [set nextObjectWithEntryIndex: &entryIndex];
}

@end