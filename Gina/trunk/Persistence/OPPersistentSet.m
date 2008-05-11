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
	return (float) usedentryCount / (float) entryCount;
}

- (id) initWithObjects: (id*) objects count: (NSUInteger) ocount
{
	if (self = [super init]) {
		for (int i=0; i<ocount; i++) {
			[self addObject: objects[i]];
		}
	}
	return self;
}



- (NSUInteger) bucketIndexForObject: (NSObject<OPPersisting>*) object returnFree: (BOOL) returnFree
/*" Returns a bucket index or NSNotFound if the object is not contained (returnFree==NO) or already contained (returnFree=YES) "*/
{
	OID        objectOID  = [object oid];
	NSUInteger objectHash = [object hash];
#warning crashes with EXC_ARITHMETIC when entryCount is 0 (division by zero?)
	NSUInteger index = objectHash % entryCount; // 1st pobe position
	NSUInteger result;
	NSUInteger lastIndex = NSNotFound;
	OPHashBucket* bucket;
	NSUInteger step  = 0;

	while ((bucket = entries[result = ((index+step) % entryCount)])->oid) {
		if (returnFree) {
			bucket->oid;
			if (bucket->oid == InvalidOID) {
				// while looking for a free spot, found a deleted entry
				return result;
			}
		} else {
			// We are looking for a matching bucket
			if (bucket->hash == objectHash) {
				if (bucket->oid == objectOID) 
					return result;
				// Found equal hash values, but different oids - need to ask the object:
				id bucketObject = [self.context objectForOID: (bucket->oid)]; // potentially slow
				if ([bucketObject isEqual: object]) {
					return result;
				}
			}
		}
		
		lastIndex = index;
		step = MAX(1, step*2); // square probing
	}
	// No bucket found, result points to an empty entry
	if (returnFree) {
		return result;
	}
	
	
	return NSNotFound;
}

//- (OID) oidMember: (OID) queryOID hash: (NSUInteger) queryHash
/*" Return, the oid of an object contained in the receiver and equal to the object referenced by queryOID as determined by -hash and isEqual. "*/

- (id) member: (id) object
{
	NSUInteger bIndex = [self bucketIndexForObject: object returnFree: NO];
	if (bIndex == NSNotFound) return nil;
	OID resultOid = entries[bIndex]->oid;
	return [self.context objectForOID: resultOid];
}


- (void) addObject: (id) object
{
	NSUInteger bIndex = [self bucketIndexForObject: object returnFree: YES];
	if (bIndex != NSNotFound) {
		NSAssert(entries[bIndex]->oid == NILOID, @"bucket found for insertion not free.");
		OPHashBucket* bucket = entries[bIndex];
		if (bucket->oid == 0) usedentryCount++;
		bucket->oid  = [object oid];
		bucket->hash = [object hash];
		[[object retain] autorelease]; // docu says we should retain, but we don't want to.
	}
}

- (void) removeObject:  (id) object
{
	// Mark bucket for object as invalid:
	NSUInteger bIndex = [self bucketIndexForObject: object returnFree: NO];
	if (bIndex != NSNotFound) {
		NSAssert(entries[bIndex]->oid != NILOID, @"bucket found for insertion not free.");

		entries[bIndex]->oid = InvalidOID;
	}
}

- (NSString*) description
{
	return [NSString stringWithFormat: @"%@, %00.00f%% used", self.usageFactor*100];
}

- (NSEnumerator*) objectEnumerator
{
	return nil;
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