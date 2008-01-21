//
//  OPPersistentObjectContext.h
//
//  Created by Dirk Theisen on 22.07.05.
//  Copyright 2005 Dirk Theisen <d.theisen@objectpark.org>. All rights reserved.
//
//
//  OPPersistence - a persistent object library for Cocoa.
//
//  For non-commercial use, you can redistribute this library and/or
//  modify it under the terms of the GNU Lesser General Public
//  License as published by the Free Software Foundation; either
//  version 2.1 of the License, or (at your option) any later version.
//
//  This library is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
//  Lesser General Public License for more details:
//
//  <http://www.gnu.org/copyleft/lesser.html#SEC1>
//
//  You should have received a copy of the GNU Lesser General Public
//  License along with this library; if not, write to the Free Software
//  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
//
//  For commercial use, commercial licenses and redistribution licenses
//  are available - including support - from the author,
//  Dirk Theisen <d.theisen@objectpark.org> for a reasonable fee.
//
//  DEFINITION Commercial use
//  This library is used commercially whenever the library or derivative work
//  is charged for more than the price for shipping and handling.
//

#import <AppKit/AppKit.h>
#import "OPDBLite.h"
#import "OPPersistenceConstants.h"
#import "OPPersistentObject.h"


@class OPPersistentObject;
@class OPFaultingArray;
@class OPKeyedArchiver;
@class OPKeyedUnarchiver;

@interface NSNumber (OPPerstistenceAdditions)
+ (NSNumber *)numberWithOID:(OID)anOid;
- (OID)OIDValue;
@end

extern NSString* OPStringFromOID(OID oid);

@interface OPPersistentObjectContext : NSObject {
    
	@private
	
	OID maxLid[256];
	Class classes[256]; // classes contained in the archive, indexed by cid
	
	NSMapTable* cidsByClass;
    NSHashTable* registeredObjects; // conceptually a set, can be queried by object or (via dummy) by oid
    NSMutableSet* changedObjects; // this object is used to lock both changedObjects and deletedObjects
    OPFaultingArray* deletedObjects;
    
    OPDBLite* database;
	NSString* databasePath;
	
	unsigned numberOfFaultsFired; // statistics
	unsigned numberOfFaultsCreated; // statistics
	unsigned numberOfObjectsSaved; // statistics
	unsigned numberOfObjectsDeleted; // statistics
	NSCountedSet* faultFireCountsByKey; // statistics
	
	/*" Maps join table names to OPObjectReleationship objects, recording the n:m relationship changes for that join table. Used to update fetched n:m relationships. "*/
	NSMutableDictionary* relationshipChangesByJoinTable;
	unsigned faultCacheSize;
	NSMutableArray* faultCache; // array of constant size (ringbuffer) retaining some often used objects so they do not get instantiated over and over again. 
	OPKeyedArchiver* encoder;
	OPKeyedUnarchiver* decoder;
	
	NSMutableDictionary* allObjectsByClass; // eagerly cached objects keys are classes, values are mutalbe sets
	
	NSMutableDictionary* rootObjects;
	NSMutableDictionary* rootObjectOIDs;
	NSCountedSet* instanceStatistic;
}

// Methods for internal use ONLY:

- (id) objectRegisteredForOID: (OID) oid;
- (void) registerObject: (id <OPPersisting>) object;
- (void) unregisterObject: (id <OPPersisting>) object;
- (void) insertObject: (id <OPPersisting>) object;
- (OID) nextOIDForClass: (Class) poClass;

- (id) rootObjectForKey: (NSString*) key;
- (void) setRootObject: (id <OPPersisting>) pObject forKey: (NSString*) key;

// Archiving to the objectTree:
- (void) archiveObject: (id) object usingCursor: (OPIntKeyBTreeCursor*) cursor;	
- (id) newUnarchivedObjectForOID: (OID) oid;

// Public Methods:

@property (readonly) NSDictionary* allObjectsByClass;

- (NSSet*) allObjectsOfClass: (Class) poClass;

- (OPKeyedArchiver*) encoder;
- (OPKeyedUnarchiver*) decoder;

- (NSSet*) changedObjects;
- (OPFaultingArray*) deletedObjects;
- (void) shouldDeleteObject: (OPPersistentObject*) object;

+ (OPPersistentObjectContext*) defaultContext;
+ (void) setDefaultContext: (OPPersistentObjectContext*) context;

- (void) setDatabaseFromPath: (NSString*) dbPath;
- (OPDBLite*) database;
- (NSString*) databasePath;

// Managing the class table:

- (Class) classForCID: (CID) cid;
- (CID) cidForClass: (Class) poClass;


// Methods for use by the appication developer:
+ (OPPersistentObjectContext*) defaultContext;
- (void) reset;
- (void) close;

- (id) objectWithURLString: (NSString*) urlString;
- (id) objectForOID: (OID) oid;

//- (void) willChangeObject: (id <OPPersisting>) object;
- (void) didChangeObject: (id <OPPersisting>) object;

- (void) willRevertObject: (id <OPPersisting>) object;
- (void) didRevertObject: (id <OPPersisting>) object;

- (void) willFireFault: (OPPersistentObject*) fault forKey: (NSString*) key;
//- (void) willAccessObject: (id <OPPersisting>) fault forKey: (NSString*) key;


- (void) saveChanges;
- (void) revertChanges;


@end

@interface NSCoder (OPPersistence)

- (OID) decodeOIDForKey: (NSString*) key;
- (void) encodeOID: (OID) oid forKey: (NSString*) key;
- (OPPersistentObjectContext*) context;

@end

extern NSString* OPURLStringFromOidAndClass(OID oid, NSString* databaseName);
