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

- (NSUInteger) entryIndexForObject: (NSObject<OPPersisting>*) object 
							   oid: (OID) objectOID
							  hash: (NSUInteger) objectHash
						returnFree: (BOOL) returnFree
/*" Returns a entries index or NSNotFound if the object is not contained (returnFree==NO) or already contained (returnFree=YES) "*/
{
	NSUInteger index = objectHash % entryCount; // 1st pobe position
	NSUInteger result;
	NSUInteger lastIndex = NSNotFound;
	OPHashEntry* entry;
	NSUInteger step  = 0;
	
	while ((entry = entries[result = ((index+step) % entryCount)])->oid) {
		if (returnFree) {
			entry->oid;
			if (entry->oid == InvalidOID) {
				// while looking for a free spot, found a deleted entry
				return result;
			}
		} else {
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
		
		lastIndex = index;
		step = MAX(1, step*2); // square probing
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
	OPHashEntry** oldEntries    = entries;
	
	entryCount = minCapacity * 2 + 1;
	entries    = calloc(entryCount, sizeof(OPHashEntry));
	NSLog(@"Resizing persistent set to hold max %u entries (%u bytes each).", entryCount, sizeof(OPHashEntry));
	// copy over old entries by adding them:
	for (int i = 0; i < oldEntryCount; i++) {
		OPHashEntry* oldEntry = oldEntries[i];
		if (oldEntry->oid > 1) {
			NSUInteger eIndex = [self entryIndexForObject: nil
													  oid: oldEntry->oid
													 hash: oldEntry->hash
											   returnFree: YES];
			NSAssert(eIndex != NSNotFound, @"No free hash entry found during hash rebuild in OPPersistentSet.");
			OPHashEntry* entry = entries[eIndex];
			usedEntryCount++;
			count++;
			// copy over entry
			*entry = *oldEntry;
			
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
	OID resultOid = entries[bIndex]->oid;
	return [self.context objectForOID: resultOid];
}



		
- (void) addObject: (id) object
{
	if (usedEntryCount + 1 <= entryCount) {
		[self rebuildWithMinCapacity: count];
	}
	
	NSUInteger bIndex = [self entryIndexForObject: object 
											  oid: [object oid]
											 hash: [object hash]
									   returnFree: YES];
	if (bIndex != NSNotFound) {
		NSAssert(entries[bIndex]->oid == NILOID, @"entry found for insertion not free.");
		OPHashEntry* entry = entries[bIndex];
		if (entry->oid == 0) usedEntryCount++;
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
		NSAssert(entries[bIndex]->oid != NILOID, @"entry found for insertion not free.");

		entries[bIndex]->oid = InvalidOID;
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
		OID oid = entries[*entryIndex]->oid;
		if (oid > InvalidOID) {
			return [self.context objectForOID: oid];
		}
		*entryIndex++;
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