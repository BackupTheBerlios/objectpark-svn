//
//  OPKeyedArchiver.h
//  BTreeLite
//
//  Created by Dirk Theisen on 18.10.07.
//  Copyright 2007 Dirk Theisen. All rights reserved.
//

#import <Foundation/Foundation.h>

@class OPPersistentObjectContext;
#import "OPPersistentObject.h";

@interface OPKeyedArchiver : NSCoder {
	//NSMutableData* blob;
	NSMutableArray* plistStack;
	NSMutableDictionary* encodingsByOid;
	unsigned tidCount; // temporary id counter, used for uniquing non-persistent objects
	OPPersistentObjectContext* context; // not retained
	NSMapTable* lidsByObjectPtrs; // keys: object pointers, values: tids
}

@property (readonly) OPPersistentObjectContext* context;

- (id) initWithContext: (OPPersistentObjectContext*) context;

- (NSData*) resultData;
- (NSData*) dataFromObject: (NSObject <OPPersisting>*) object;


 // For debugging only:
- (NSDictionary*) resultPlist;

@end
