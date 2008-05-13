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

static NSUInteger prims[] = {3,5,7,11,17,23,29,37,43,53,113,193,271,359,443,541,619,719,821,911,1013,1097,1213,1429,1511,1609,1721,1831,1949,2053,2143,2273,2377,2473,2617,2707,2801,2917,3041,3181,3301,3391,3527,3617,3727,3851,3947,4079,4211,4297,4447,4561,4673,4799,4937,5023,5167,5297,5419,5521,5653,5779,5867,6029,6133,6263,6359,6491,6637,6761,6869,6983,7121,7243,7411,7529,7621,7741,7879,8017,8161,8273,8419,8543,8677,8779,8893,9029,9161,9283,9413,9511,9649,9781,9887,10061,10567,11383,11503,12049,12197,12323,12451,12553,12671,12821,12953,13751,13879,14011,14957,15121,15259,15359,16007,16447,16603,16729,16889,17551,17683,17839,17971,18097,18223,18341,18461,18637,18793,18979,19141,19273,19423,19507,19687,19813,19961,20071,20183,20347,20929,21589,21737,21859,22409,22567,22699,22817,22993,23081,23813,23917,24061,24169,24359,24499,24677,25127,25261,25411,25579,25693,25847,25981,26821,26951,27077,27259,27431,27583,27743,27827,27983,28111,28297,28447,29131,29873,30059,30931,31079,31193,31321,31511,31649,31793,31991,32117,32257,32371,32503,32621,32789,32939,33053,33199,33349,33493,33613,33751,33871,34039,34217,34337,34487,34613,34757,34913,35083,35227,36137,36299,36469,36587,36721,36857,36979,37139,37309,37447,37567,37693,37879,38047,38821,38959,39113,39233,39373,39541,39709,39841,39983,40813,40933,41081,41213,41357,41519,41641,41801,41941,42061,42727,42859,43013,43189,43397,43573,43691,43867,44017,44129,44269,44483,44617,44741,44887,45053,45197,45343,45533,45677,45833,46021,46171,46309,46477,46633,46757,46901,47699,47819,47969,48157,48313,48479,48611,48767,48883,49043,49193,49787,49927,50069,50207,50867,51031,51871,52027,52183,52361,52541,52691,53117,53269,53419,53609,53731,53891,54037,54217,54377,54503,54629,54787,54973,55117,55291,55457,55631,55763,55889,56039,56179,56369,56489,56629,56773,56909,57041,57173,57301,58073,58901,59021,59141,59273,59887,60083,60217,61027,61991,62137,62303,62483,62633,62801,62971,63691,63809,64007,64171,64333,64567,64693,64879,65033,65171,65327,65497,65617,65729,65899,66067,66239,66431,66571,66739,66889,67049,67187,67343,67481,67601,67763,67927,68059,68227,68449,68597,68749,68903,69073,69239,69403,69557,69779,69941,70111,70223,70379,70529,70667,70867,70981,71147,71879,71999,72161,72287,72481,72649,72797,72937,73063,73303,73939,74099,74219,74381,74531,74713,74843,75011,75181,75329,75503,75619,75767,75941,76099,76919,77093,77261,77383,78301,78497,78643,78803,78977,79153,79309,79433,79621,79801,79903,80077,80831,81001,81101,81283,81439,81619,81749,81929,82037,82207,82351,82507,82651,82811,83009,84017,84793,84979,85121,85933,86137,86929,87103,87977,88211,89057,89209,89381,89519,89963,90071,90217,90397,90533,90709,90907,91097,92221,92363,92479,92647,92767,92899,93083,93239,93371,93523,93719,93911,94049,94219,94379,94531,94687,94837,95003,95891,96043,96223,96857,97021,97213,97397,99991,120181,150151,4200003,250049,304279,350237,400109,450001,504187,550553,600361,657299,706669,752821,801631,859093,941509,999983};

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

- (void) dealloc
{
	if (entries) free(entries);
	[super dealloc];	
}

- (NSUInteger) entryIndexForObject: (NSObject<OPPersisting>*) object 
							   oid: (OID) objectOID
							  hash: (NSUInteger) objectHash
						returnFree: (BOOL) returnFree
/*" Returns an index in the entries array or NSNotFound if the object given is not contained (returnFree==NO) or already contained (returnFree=YES). For returnFree=YES the first index suitable for insertion is returned. object, objectOID and objectHash must match. object may be nil if objectOID and objectHash are given. "*/
{
	NSUInteger  result;
	OPHashEntry* entry;
	NSUInteger  step  = 0;
	
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
		if (entryCount > 2*minCapacity) {
			break;
		}
	}
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
		NSLog(@"Shrinking persistent set...");
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


//- (void) encodeWithCoder: (NSCoder*) coder

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