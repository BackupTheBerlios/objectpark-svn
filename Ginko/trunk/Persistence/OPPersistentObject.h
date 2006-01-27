//
//  OPPersistentObject.h
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
@class OPClassDescription;

@interface OPPersistentObject : NSObject {
    @public 
	const OID oid;
	@protected
    NSMutableDictionary* attributes;
}

+ (NSString*) persistentAttributesPlist;
+ (NSString*) databaseProperties;

+ (OPClassDescription*) persistentClassDescription;

- (id) initFaultWithContext: (OPPersistentObjectContext*) context 
						oid: (OID) anOid;

- (void) insertIntoContext: (OPPersistentObjectContext*) context;


- (NSDictionary*) attributeValues;
- (BOOL) hasChanged;

- (OPPersistentObjectContext*) context;
- (BOOL) isFault;
- (BOOL) isDeleted;
- (BOOL) resolveFault;
- (void) willDelete;

- (OID) oid;
- (NSString*) objectURLString;

- (id) transientValueForKey: (NSString*) key;
- (void) setTransientValue: (id) value forKey: (NSString*) key;

- (id) primitiveValueForKey: (NSString*) key;
- (void) setPrimitiveValue: (id) object forKey: (NSString*) key;
- (void) refault;
- (void) revert;
- (void) delete;

- (OID) currentOid; // internal method
- (void) setOid: (OID) theOid; // for internal use

- (void) willSave;
- (void) willChangeValueForKey: (NSString*) key;
- (void) willAccessValueForKey: (NSString*) key;
- (void) didChangeValueForKey: (NSString*) key;
- (void) didAccessValueForKey: (NSString*) key;

- (void) willChangeToManyRelationshipForKey: (NSString*) key;
- (void) didChangeToManyRelationshipForKey: (NSString*) key;

- (NSString*) descriptionIncludingAttributes: (BOOL) printAttributes;

- (void) addValue: (id) value forKey: (NSString*) key;
- (void) addPrimitiveValue: (id) value forKey: (NSString*) key;
- (void) removeValue: (id) value forKey: (NSString*) key;
- (void) removePrimitiveValue: (id) value forKey: (NSString*) key;

- (NSArray*) validationErrors;


@end
