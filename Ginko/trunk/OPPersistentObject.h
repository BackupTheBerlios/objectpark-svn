//
//  OPPersistentObject.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 22.07.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OPPersistenceConstants.h"

@class OPPersistentObjectContext;

@interface OPPersistentObject : NSObject {
    OID oid;
    NSMutableDictionary* attributes;
}

+ (NSString*) databaseTableName;

+ (NSArray*) databaseAttributeNames;
+ (NSArray*) objectAttributeNames;
+ (NSArray*) objectAttributeClasses;


- (id) initWithContext: (OPPersistentObjectContext*) context 
                   oid: (OID) anOid;

- (OPPersistentObjectContext*) context;
- (BOOL) isFault;
- (BOOL) resolveFault;
- (OID) oid;
- (id) persistentValueForKey: (NSString*) key;
- (void) setPersistentValue: (id) object forKey: (NSString*) key;
- (void) refault;

@end
