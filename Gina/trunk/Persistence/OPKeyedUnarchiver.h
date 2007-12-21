//
//  OPKeyedUnarchiver.h
//  BTreeLite
//
//  Created by Dirk Theisen on 21.10.07.
//  Copyright 2007 Dirk Theisen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OPPersistenceConstants.h"
#import "OPPersistentObject.h"

@class OPPersistentObjectContext;

@interface OPKeyedUnarchiver : NSCoder {
	NSMutableArray* plistStack;
	NSDictionary* encodingsByOid;
	NSMutableDictionary* objectsByOid;
	OPPersistentObjectContext* context;
}

- (id) initWithContext: (OPPersistentObjectContext*) aContext;

- (BOOL)containsValueForKey:(NSString *)key;
- (id)decodeObjectForKey:(NSString *)key;
- (BOOL)decodeBoolForKey:(NSString *)key;
- (int)decodeIntForKey:(NSString *)key;
- (int32_t)decodeInt32ForKey:(NSString *)key;
- (int64_t)decodeInt64ForKey:(NSString *)key;
- (float)decodeFloatForKey:(NSString *)key;
- (double)decodeDoubleForKey:(NSString *)key;
- (const uint8_t *)decodeBytesForKey:(NSString *)key returnedLength:(NSUInteger *)lengthp;   // returned bytes immutable!

- (void) unarchiveObject: (OPPersistentObject<NSCoding>*) result
				fromData: (NSData*) blob;

@end
