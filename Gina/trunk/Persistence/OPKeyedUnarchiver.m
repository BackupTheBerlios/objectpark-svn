//
//  OPKeyedUnarchiver.m
//  BTreeLite
//
//  Created by Dirk Theisen on 21.10.07.
//  Copyright 2007 Dirk Theisen. All rights reserved.
//

#import "OPKeyedUnarchiver.h"
#import "OPPersistentObjectContext.h"
#import "OPPersistentObject.h"

@implementation OPKeyedUnarchiver

@synthesize context;

- (id) initWithContext: (OPPersistentObjectContext*) aContext;
{
	if (self = [super init]) {
		context = aContext; // not retained
		plistStack = [[NSMutableArray alloc] initWithCapacity: 10];
		objectsByOid = [[NSMutableDictionary alloc] initWithCapacity: 10];
	}
	return self;
}

- (void) dealloc 
{
	[plistStack release];
	[objectsByOid release];
	[encodingsByOid release];
	[super dealloc];
}

- (BOOL) allowsKeyedCoding
{
	return YES;
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

- (void) pushStack: (NSDictionary*) newDict
{
	[plistStack addObject: newDict];
}

- (void) popStack
{
	[plistStack removeLastObject];
}


- (BOOL) containsValueForKey: (NSString*) key
{
	return [[self topStack] objectForKey: key] != nil;
}

- (id) decodeObjectForKey: (NSString*) key
{
	id plistValue = [[self topStack] objectForKey: key];
	if ([plistValue isPlistMemberClass]) {
		// plist types can be returned directly:
		return [plistValue retain];
	} 
	// Extract oid for key:
	OID oid = [plistValue unsignedLongLongValue];
	NSString* oidString = [NSString stringWithFormat: @"%016llx", oid]; // eliminate later
	
	id result = [objectsByOid objectForKey: oidString];
	
	if (result) return result;
 	
	NSDictionary* objectPlist = [encodingsByOid objectForKey: oidString];	
	
	if (objectPlist) {
		[self pushStack: objectPlist];
		Class poClass = [context classForCID: CIDFromOID(oid)];
		if (poClass) {
			result = [poClass alloc];
			[objectsByOid setObject: result forKey: oidString];
			result = [result initWithCoder: self];
		} else {
			NSLog(@"Warning, unknown class for oid 0x%llx", oid);
		}
		[self popStack];
	}
	return result;
}

- (OID) decodeOIDForKey: (NSString*) key
{
	return [self decodeInt64ForKey: key];
}

- (void) unarchiveObject: (OPPersistentObject<NSCoding>*) result
				fromData: (NSData*) blob
/*" Initializes the given allocated object from the data given. does nothing for nil results."*/
{
	if (! result) return;
	
	NSParameterAssert([result currentOID] > 0);
	NSParameterAssert(blob != nil);

	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	NSString* error = nil;
	OID oid = [result currentOID];
	// 'load' plist:
	encodingsByOid = [[NSPropertyListSerialization propertyListFromData: blob mutabilityOption: 0 format: NULL errorDescription: &error] retain];
	[objectsByOid removeAllObjects];
	[pool release]; pool = [[NSAutoreleasePool alloc] init];
	
	// Prepare decoder:
	//Class poClass = [context classForCid: CIDFromOID(oid)];
	NSString* oidString = [NSString stringWithFormat: @"%016llx", oid]; // eliminate later
	NSDictionary* objectPlist = [encodingsByOid objectForKey: oidString];
	if (objectPlist) {
		[self pushStack: objectPlist];
		//result = [poClass alloc];
		[objectsByOid setObject: result forKey: oidString];
		result = [result initWithCoder: self];
		[self popStack];
	}
	[pool release];
	[encodingsByOid release]; encodingsByOid = nil;
	[objectsByOid removeAllObjects];
}


- (BOOL) decodeBoolForKey: (NSString*) key
{
	NSNumber* value = [[self topStack] objectForKey: key];
	//[[resultStack lastObject] setValue: value forKey: key];
	return value ? [value boolValue] : NO;
}

- (int) decodeIntForKey: (NSString*) key
{
	NSNumber* value = [[self topStack] objectForKey: key];
	//[[resultStack lastObject] setValue: value forKey: key];	
	return value ? [value intValue] : 0;
}

- (int32_t)decodeInt32ForKey:(NSString*) key
{
	NSNumber* value = [[self topStack] objectForKey: key];
	///[[resultStack lastObject] setValue: value forKey: key];
	return value ? [value longValue] : 0;
}

- (int64_t) decodeInt64ForKey: (NSString*) key
{
	NSNumber* value = [[self topStack] objectForKey: key];
	//[[resultStack lastObject] setValue: value forKey: key];
	return value ? [value longLongValue] : 0;
}

- (float) decodeFloatForKey: (NSString*) key
{
	NSNumber* value = [[self topStack] objectForKey: key];
	//[[resultStack lastObject] setValue: value forKey: key];
	return value ? [value floatValue] : 0.0;
}

- (double) decodeDoubleForKey: (NSString*) key
{
	NSNumber* value = [[self topStack] objectForKey: key];
	//[[resultStack lastObject] setValue: value forKey: key];
	return value ? [value doubleValue] : 0.0;
}

- (const uint8_t *) decodeBytesForKey: (NSString*) key 
					  returnedLength: (NSUInteger*) lengthp
{
	NSData* value = [[self topStack] objectForKey: key];
	*lengthp = [value length];
	return [value bytes]; // who retains this?
}

@end
