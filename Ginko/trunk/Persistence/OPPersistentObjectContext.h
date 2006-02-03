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
#include <sqlite3.h>
#import "OPPersistenceConstants.h"

@class OPPersistentObject;
@class OPSQLiteConnection;
@class OPPersistentObjectEnumerator;
@class OPFaultingArray;
@class OPObjectRelationship;
@class OPAttributeDescription;

@interface OPPersistentObjectContext : NSObject {
    
	@private
    NSHashTable* registeredObjects;
    NSMutableSet* changedObjects;
    NSMutableSet* deletedObjects;
    
    OPSQLiteConnection* db;
	
	unsigned numberOfFaultsFired; // statistics
	unsigned numberOfRelationshipsFired; // statistics
	unsigned numberOfFaultsCreated; // statistics
	unsigned numberOfObjectsSaved; // statistics
	unsigned numberOfObjectsDeleted; // statistics
	NSCountedSet* faultFireCountsByKey; // statistics
	
	/*" Maps join table names to OPObjectReleationship objects, recording the n:m relationship changes for that join table. Used to update fetched n:m relationships. "*/
	NSMutableDictionary* relationshipChangesByJoinTable;
	unsigned faultCacheSize;
	NSMutableArray* faultCache; // array of constant size (ringbuffer) retaining some often used objects so they do not get instantiated over and over again. 
	NSMutableDictionary* cachedObjectsByClass;
}

// Methods for internal use ONLY:

- (id) objectRegisteredForOid: (OID) oid ofClass: (Class) poClass;
- (void) registerObject: (OPPersistentObject*) object;
- (void) unregisterObject: (OPPersistentObject*) object;
- (void) insertObject: (OPPersistentObject*) object;

		
// Public Methods:

- (NSArray*) allObjectsOfClass: (Class) poClass;


- (NSSet*) changedObjects;
- (NSSet*) deletedObjects;
- (NSDictionary*) persistentValuesForObject: (OPPersistentObject*) object;
- (OID) newDatabaseObjectForObject: (OPPersistentObject*) object;
- (void) shouldDeleteObject: (OPPersistentObject*) object;

+ (void) setDefaultContext: (OPPersistentObjectContext*) context;

- (void) setDatabaseConnectionFromPath: (NSString*) dbPath;
- (OPSQLiteConnection*) databaseConnection;
- (void) setDatabaseConnection: (OPSQLiteConnection*) newConnection;

// Methods for use by the appication developer:
+ (OPPersistentObjectContext*) defaultContext;
- (void) reset;

- (id) objectWithURLString: (NSString*) urlString;
- (id) objectForOid: (OID) oid ofClass: (Class) poClass;

//- (void) willChangeObject: (OPPersistentObject*) object;
- (void) didChangeObject: (OPPersistentObject*) object;

- (void) willRevertObject: (OPPersistentObject*) object;
- (void) didRevertObject: (OPPersistentObject*) object;

- (void) willFireFault: (OPPersistentObject*) fault forKey: (NSString*) key;
//- (void) willAccessObject: (OPPersistentObject*) fault forKey: (NSString*) key;


- (void) saveChanges;
- (void) revertChanges;

- (NSArray*) fetchObjectsOfClass: (Class) poClass
				 queryFormat: (NSString*) clause, ...;

- (NSArray*) fetchObjectsOfClass: (Class) poClass
				 whereFormat: (NSString*) clause, ...;

- (OPFaultingArray*) containerForObject: (id) object
						relationShipKey: (NSString*) key;

- (void) checkDBSchemaForClasses: (NSString*) classListSeparatedByComma;

- (OPObjectRelationship*) manyToManyRelationshipForAttribute: (OPAttributeDescription*) ad;


@end

@class OPFaultingArray;

@interface OPPersistentObjectEnumerator : NSEnumerator {
	sqlite3_stmt* statement;
	Class resultClass;
	OPPersistentObjectContext* context;
}

- (id) initWithContext: (OPPersistentObjectContext*) aContext
		   resultClass: (Class) poClass 
		   queryString: (NSString*) sql;

- (id) initWithContext: (OPPersistentObjectContext*) aContext
		   resultClass: (Class) poClass 
		   whereClause: (NSString*) clause;

- (void) reset;
- (BOOL) skipObject;
- (sqlite3_stmt*) statement;

+ (void) printAllRunningEnumerators;

//- (void) bind: (id) variable, ...;

- (OPFaultingArray*) allObjectsSortedByKey: (NSString*) sortKey ofClass: (Class) sortKeyClass;


@end

extern NSString* OPURLStringFromOidAndClass(OID oid, Class poClass, NSString* databaseName);
