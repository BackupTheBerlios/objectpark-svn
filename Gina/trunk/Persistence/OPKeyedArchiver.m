//
//  OPKeyedArchiver.m
//  BTreeLite
//
//  Created by Dirk Theisen on 18.10.07.
//  Copyright 2007 Dirk Theisen. All rights reserved.
//

#import "OPKeyedArchiver.h"
#import "OPPersistentObject.h"
#import "OPPersistentObjectContext.h"
#import <Foundation/NSDebug.h>

@implementation OPKeyedArchiver


- (id) init
{
	NSParameterAssert(NO);
	return nil;
}

- (NSDictionary*) resultPlist
{
	return encodingsByOid;
}

- (NSData*) resultData
{
	NSDictionary* plist = [self resultPlist];
	if (! plist) return nil;
	
	NSData* result = nil;
		
	result = [NSPropertyListSerialization dataFromPropertyList: plist 
														format: kCFPropertyListBinaryFormat_v1_0 
											  errorDescription: nil];
	return result;
}

- (NSData*) dataFromObject: (OPPersistentObject*) object
{
	[self encodeRootObject: object];
	//if (NSDebugEnabled) NSLog(@"Encoding %@ to plist: %@", object, [self resultPlist]);
	return [self resultData];
}

- (id) initWithContext: (OPPersistentObjectContext*) theContext
{
	if (self = [super init]) {
		context    = theContext;
		plistStack = [[NSMutableArray alloc] initWithCapacity: 5];
		encodingsByOid = [[NSMutableDictionary alloc] init];
	}
	return self;
}


- (void) dealloc
{
	if (lidsByObjectPtrs) NSFreeMapTable(lidsByObjectPtrs);
	[plistStack release];
	[encodingsByOid release];
	[super dealloc];
}

- (BOOL) allowsKeyedCoding
{
	return YES;
}

- (void)encodeValueOfObjCType:(const char *)type at:(const void *)addr
{
	NSParameterAssert(NO);
}

- (void)encodeDataObject:(NSData *)data
{
	NSParameterAssert(NO);
}

- (NSInteger) versionForClassName: (NSString*) className
{
	return 1;
}

/*" Returns the top of the stack. Should migrate this to use NSMapTables and serialize those to NSDatas. "*/
- (NSMutableDictionary*) topStack
{
	NSMutableDictionary* result = [plistStack lastObject];
	NSAssert(result != nil, @"Internal Error in Keyed Archiver. Try to access an empty stack.");
	return result;
}

- (NSMutableDictionary*) pushedStack
{
	NSMutableDictionary* newDict = [[NSMutableDictionary alloc] init];
	[plistStack addObject: newDict];
	[newDict release];
	return newDict;
}

- (void) popStack
{
	[plistStack removeLastObject];
}

- (void) encodeRootObject: (id) rootObject
/*" rootObject must be an OPPersistentObject. "*/
{
	NSParameterAssert([[rootObject classForCoder] canPersist]);
	[plistStack removeAllObjects];
	[encodingsByOid removeAllObjects];
	if (lidsByObjectPtrs) NSFreeMapTable(lidsByObjectPtrs);
	lidsByObjectPtrs = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks, NSIntegerMapValueCallBacks, 10);
	
	tidCount = 1; // replaces lid in tids (temporary ids)
	
	if (!rootObject) return;

	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

	OID oid = [rootObject oid];
	
	if (oid == NILOID) {
		[context insertObject: rootObject];
		oid = [rootObject oid];
	}
	
	NSParameterAssert(oid != NILOID);

	// Record root objects lid:
	NSMapInsertKnownAbsent(lidsByObjectPtrs, rootObject, (void*)(unsigned)LIDFromOID(oid));
	
	NSString* oidString = [NSString stringWithFormat: @"%016llx", oid]; // eliminate later
	NSMutableDictionary* newTop = [self pushedStack];
	[encodingsByOid setObject: newTop forKey: oidString];	
	[rootObject encodeWithCoder: self];
	[self popStack];
	
	// Do not pop the stack here to leave some result.
	[pool release];
}


- (OID) tidForObject: (id) obj
{
	// Keep track of objects here, check, if we have assigned a tid already:
	CID cid = [context cidForClass: [obj classForCoder]];
	unsigned lid = (unsigned)NSMapGet(lidsByObjectPtrs, obj);
	if (lid) {
		return MakeOID(cid, lid);
	}
	
	// Assign new tid:
	OID result = MakeOID(cid, tidCount);
	
	NSMapInsertKnownAbsent(lidsByObjectPtrs, obj, (void*) tidCount);
	tidCount++;
	return result;
}

static Class oppClass    = nil;
//static Class stringClass = nil; 
//static Class numberClass = nil; 
//static Class dataClass   = nil; 
//
+ (void) load
{
	oppClass    = [OPPersistentObject classForCoder];
//	stringClass = [NSString classForCoder];
//	numberClass = [NSNumber classForCoder];
//	dataClass   = [NSData classForCoder];
}

- (void) encodeObject: (id) objv forKey: (NSString *) key
{
	if (!objv) return;
	
	OID oid;
	// Persistent objects are encoded as their oids;
	if ([objv isKindOfClass: oppClass]) {
		if ([objv oid] == NILOID) {
			[context insertObject: objv];
			oid = [objv oid];
		}
	} else {
		
		// Put plist types into the plist directly:
		if ([objv isPlistMemberClass]) {
			[[self topStack] setObject: objv forKey: key];
			return;
		}
		
		oid = [self tidForObject: objv];
	}
	
	NSParameterAssert(oid != NILOID);

	[self encodeInt64: oid forKey: key];

	NSString* oidString = [NSString stringWithFormat: @"%016llx", oid];

	// Test, if the object has already been encoded in this chunk:
	if (! [encodingsByOid objectForKey: oidString]) {
		NSMutableDictionary* newTop = [self pushedStack];
		[encodingsByOid setObject: newTop forKey: oidString];	
		[objv encodeWithCoder: self];
		[self popStack];
	}
}

- (void) encodeConditionalObject: (id) objv forKey: (NSString*) key
{
	// What else should we do here?
	[self encodeObject: objv forKey: key];
}

- (void) encodeBool: (BOOL) boolv forKey: (NSString*) key
{
	if (boolv == NO) return;
	
	NSNumber* element = [[NSNumber alloc] initWithBool: boolv];
	[[self topStack] setObject: element forKey: key];
	[element release];
}

- (void)encodeInt:(int)intv forKey:(NSString *)key
{
	if (intv == 0) return;

	NSNumber* element = [[NSNumber alloc] initWithInt: intv];
	[[self topStack] setObject: element forKey: key];
	[element release];
}

- (void)encodeInt32:(int32_t)intv forKey:(NSString *)key
{
	if (intv == 0) return;

	NSNumber* element = [[NSNumber alloc] initWithLong: intv];
	[[self topStack] setObject: element forKey: key];
	[element release];
}

- (void) encodeInt64: (int64_t) intv forKey:(NSString *)key
{
	if (intv == 0) return;
	
	NSNumber* element = [[NSNumber alloc] initWithLongLong: intv];
	[[self topStack] setObject: element forKey: key];
	[element release];
}

- (void) encodeFloat: (float) realv forKey:(NSString *)key
{
	if (realv == 0.0) return;

	NSNumber* element = [[NSNumber alloc] initWithFloat: realv];
	[[self topStack] setObject: element forKey: key];
	[element release];
}

- (void) encodeDouble: (double) realv forKey:(NSString *)key
{
	if (realv == 0.0) return;
	
	NSNumber* element = [[NSNumber alloc] initWithDouble: realv];
	[[self topStack] setObject: element forKey: key];
	[element release];
}

- (void) encodeBytes: (const uint8_t *) bytesp length: (NSUInteger) lenv forKey: (NSString*) key
{
	NSData* element = [[NSData alloc] initWithBytes: bytesp length: lenv];
	[[self topStack] setObject: element forKey: key];
	[element release];
}


@end
