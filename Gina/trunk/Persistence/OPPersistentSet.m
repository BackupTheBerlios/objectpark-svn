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

static NSUInteger prims[] = {3,5,7,11,17,19,23,29,31,37,41,43,53,113,193,271,359,443,541,619,719,821,911,1013,1097,1213,1301,1429,1511,1609,1721,1831,1949,2053,2143,2273,2377,2473,2617,2707,2801,2917,3041,3181,3301,3391,3527,3617,3727,3851,3947,4079,4211,4297,4447,4561,4673,4799,4937,5023,5167,5297,5419,5521,5653,5779,5867,6029,6133,6263,6359,6491,6637,6761,6869,6983,7121,7243,7411,7529,7621,7741,7879,8017,8161,8273,8419,8543,8677,8779,8893,9029,9161,9283,9413,9511,9649,9781,9887,10061,10163,10289,10429,10567,10691,10847,10973,11113,11251,11383,11503,11681,11813,11933,12049,12197,12323,12451,12553,12671,12821,12953,13063,13187,13337,13477,13633,13751,13879,14011,14173,14341,14461,14593,14731,14831,14957,15121,15259,15359,15473,15629,15739,15881,16007,16139,16301,16447,16603,16729,16889,17021,17159,17317,17419,17551,17683,17839,17971,18097,18223,18341,18461,18637,18793,18979,19141,19273,19423,19507,19687,19813,19961,20071,20183,20347,20479,20639,20771,20929,21059,21187,21341,21491,21589,21737,21859,22013,22123,22273,22409,22567,22699,22817,22993,23081,23227,23371,23561,23671,23813,23917,24061,24169,24359,24499,24677,24841,24977,25127,25261,25411,25579,25693,25847,25981,26119,26261,26399,26557,26699,26821,26951,27077,27259,27431,27583,27743,27827,27983,28111,28297,28447,28579,28669,28813,28961,29131,29251,29399,29567,29717,29873,30059,30181,30319,30493,30649,30803,30931,31079,31193,31321,31511,31649,31793,31991,32117,32257,32371,32503,32621,32789,32939,33053,33199,33349,33493,33613,33751,33871,34039,34217,34337,34487,34613,34757,34913,35083,35227,35381,35527,35729,35863,35999,36137,36299,36469,36587,36721,36857,36979,37139,37309,37447,37567,37693,37879,38047,38219,38333,38561,38693,38821,38959,39113,39233,39373,39541,39709,39841,39983,40129,40283,40487,40627,40813,40933,41081,41213,41357,41519,41641,41801,41941,42061,42197,42337,42457,42589,42727,42859,43013,43189,43397,43573,43691,43867,44017,44129,44269,44483,44617,44741,44887,45053,45197,45343,45533,45677,45833,46021,46171,46309,46477,46633,46757,46901,47119,47279,47407,47543,47699,47819,47969,48157,48313,48479,48611,48767,48883,49043,49193,49339,49477,49633,49787,49927,50069,50207,50359,50527,50683,50867,51031,51197,51343,51461,51593,51721,51871,52027,52183,52361,52541,52691,52837,52973,53117,53269,53419,53609,53731,53891,54037,54217,54377,54503,54629,54787,54973,55117,55291,55457,55631,55763,55889,56039,56179,56369,56489,56629,56773,56909,57041,57173,57301,57487,57653,57787,57923,58073,58211,58379,58537,58693,58901,59021,59141,59273,59419,59567,59707,59887,60083,60217,60383,60601,60719,60887,61027,61223,61381,61543,61657,61837,61991,62137,62303,62483,62633,62801,62971,63127,63317,63439,63587,63691,63809,64007,64171,64333,64567,64693,64879,65033,65171,65327,65497,65617,65729,65899,66067,66239,66431,66571,66739,66889,67049,67187,67343,67481,67601,67763,67927,68059,68227,68449,68597,68749,68903,69073,69239,69403,69557,69779,69941,70111,70223,70379,70529,70667,70867,70981,71147,71293,71411,71549,71713,71879,71999,72161,72287,72481,72649,72797,72937,73063,73303,73459,73607,73751,73939,74099,74219,74381,74531,74713,74843,75011,75181,75329,75503,75619,75767,75941,76099,76259,76441,76597,76771,76919,77093,77261,77383,77543,77659,77783,77977,78157,78301,78497,78643,78803,78977,79153,79309,79433,79621,79801,79903,80077,80231,80369,80567,80687,80831,81001,81101,81283,81439,81619,81749,81929,82037,82207,82351,82507,82651,82811,83009,83207,83341,83471,83641,83843,84017,84181,84319,84463,84649,84793,84979,85121,85297,85451,85619,85781,85933,86137,86269,86389,86539,86743,86929,87103,87253,87421,87553,87679,87811,87977,88211,88411,88609,88793,88897,89057,89209,89381,89519,89653,89819,89963,90071,90217,90397,90533,90709,90907,91097,91229,91381,91529,91733,91909,92051,92221,92363,92479,92647,92767,92899,93083,93239,93371,93523,93719,93911,94049,94219,94379,94531,94687,94837,95003,95143,95273,95441,95581,95737,95891,96043,96223,96401,96553,96739,96857,97021,97213,97397,99991};

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
	NSUInteger    oldEntryCount = entryCount;
	OPHashEntry*  oldEntries    = entries;
	
	for (int i=0; i<sizeof(prims); i++) {
		entryCount = prims[i];
		if (entryCount > 2*minCapacity) {
			break;
		}
	}
	
	//entryCount = MAX(minCapacity * 2 + 1, 5);
	entries    = calloc(entryCount, sizeof(OPHashEntry));
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



		
- (void) addObject: (id) object
{
	if (usedEntryCount + 1 >= entryCount) {
		[self rebuildWithMinCapacity: count];
	}
	
	NSUInteger eIndex = [self entryIndexForObject: object 
											  oid: [object oid]
											 hash: [object hash]
									   returnFree: YES];
	if (eIndex != NSNotFound) {
		OPHashEntry* entry = entries + eIndex;
		NSAssert(entry->oid <= InvalidOID, @"entry found for insertion not free.");

		if (entry->oid == NILOID) usedEntryCount++;
		entry->oid  = [object oid];
		entry->hash = [object hash];
		count++;
		[[object retain] autorelease]; // docu says we should retain, but we don't want to.
	}
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
}

- (NSString*) description
{
	return [NSString stringWithFormat: @"%@, %00.00f%% used", self.usageFactor*100];
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

//- (id) initWithCoder: (NSCoder*) coder


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