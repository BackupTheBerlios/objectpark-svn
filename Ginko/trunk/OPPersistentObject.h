//
//  OPPersistentObject.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 22.07.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OPPersistenceConstants.h"


/*
 * New persistent object life cycle
 * 
 * It is regularly created using alloc init or any  custom initializer. It does not have an object id (oid) and is not registered with a context.
 * It is added to the context. This registeres the object with the context, creates the attribute dictionary and marks it as changed. Therefor, it will be retained by the context.
 * (Whenever the -oid method is called for a new object, an oid is generated from the database without its attribute values being stored.)
 * Attribute values are set by the application.
 * On - saveChanges, the attribute values are committed to the database, requesting the oids of all persistent object attribute values. An oid is set for the object.
 */

@class OPPersistentObjectContext;

@interface OPPersistentObject : NSObject {
    OID oid;
    NSMutableDictionary* attributes;
}

+ (NSString*) databaseTableName;

+ (NSString*) persistentAttributesPlist;

- (id) initFaultWithContext: (OPPersistentObjectContext*) context 
						oid: (OID) anOid;

- (NSDictionary*) attributeValues;
- (BOOL) hasChanged;

- (OPPersistentObjectContext*) context;
- (BOOL) isFault;
- (BOOL) resolveFault;
- (OID) oid;
- (id) persistentValueForKey: (NSString*) key;
- (void) setPersistentValue: (id) object forKey: (NSString*) key;
- (void) refault;
- (OID) currentOid; // internal method
- (void) saveChanges; // internal method

@end
