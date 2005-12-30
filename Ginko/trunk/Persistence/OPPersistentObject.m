//
//  OPPersistentObject.m
//  GinkoVoyager
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

#import "OPPersistentObject.h"
#import "OPPersistentObjectContext.h"
#import "OPClassDescription.h"
#import <Foundation/NSDebug.h>
#import "OPObjectRelationship.h"
#import "GIThread.h"

@implementation OPPersistentObject


/*
+ (void) initialize
{

}
*/

+ (NSString*) databaseProperties;
	/*" Overwrite this in subclass. Default implementation returns empty dictionary. 
	 *  Used keys are TableName and CreateStatements.
 	"*/
{
	return @"{}";
}
+ (NSString*) persistentAttributesPlist
	/*" Overwrite this in subclass. Default implementation returns empty dictionary. "*/
{
	return @"{}";
}

+ (OPClassDescription*) persistentClassDescription
{
	static NSMutableDictionary* descriptionsByClass = nil;
	
	if (!descriptionsByClass) {
		descriptionsByClass = [[NSMutableDictionary alloc] init];
	}
	
	OPClassDescription* result = [descriptionsByClass objectForKey: self];
	if (!result) {
		// Create and cache the classDescription:
		result = [[[OPClassDescription alloc] initWithPersistentClass: self] autorelease];
		//NSLog(@"Created ClassDescription %@", result);
		[descriptionsByClass setObject: result forKey: self];
	}
	return result;
}


/*
+ (NSArray*) databaseAttributeNames
//" Can overwrite this in subclass. Defaults to +[objectAttributeNames]."
{
    return [self objectAttributeNames];
}

+ (NSArray*) objectAttributeNames
//" Overwrite this in subclass. "
{
    return nil;
}

+ (NSArray*) objectAttributeClasses
{
    return nil;
}
*/

+ (BOOL) canPersist
{
	return YES;
}

- (void) bindValueToStatement: (sqlite3_stmt*)  statement index: (int) index
{
	sqlite3_bind_int64(statement, index, [self oid]);
}

- (void) insertIntoContext: (OPPersistentObjectContext*) context
{
	OPPersistentObjectContext* previousContext = [self context];
	NSParameterAssert(previousContext == context || previousContext == nil);

	[context willChangeObject: self];
	NSParameterAssert(oid==0);
	// Create attributes dictionary as necessary
	if (!attributes) {
		NSLog(@"Creating attribute dictionary for object %@", self);
		attributes = [[NSMutableDictionary alloc] init]; // should set default values here?
	}
	[context didChangeObject: self];
}

- (id) initFaultWithContext: (OPPersistentObjectContext*) context 
						oid: (OID) anOid
{
	if (self = [self init]) {
		NSParameterAssert(anOid>0);
		// Set the context here in the future
		[self setOid: anOid];
	}
    return self;
}

- (OPPersistentObjectContext*) context
/*" Returns the context for the receiver. Currently, always returns the default context. "*/
{
    return [OPPersistentObjectContext defaultContext]; // simplistic implementation; prepared for multiple contexts.
}

- (BOOL) resolveFault
/*" Returns YES, if the reciever is not a fault afterwards. "*/
{
    if (attributes==nil) {
        // implement using the default PersistentObjectContext:
        attributes = [[[self context] persistentValuesForObject: self] retain];
		if (!attributes && oid==0) {
			attributes = [[NSMutableDictionary alloc] init]; // should set default values here?
			NSLog(@"Created attribute dictionary for new object %@", self);
		}
    }
	return attributes != nil;
}

- (void) revert
{
/*" Turns the receiver back into a fault, releasing attribute values. 
	Changes done since the last -saveChanges are lost. "*/
	id context = [self context];
	[context willRevertObject: self];
	[attributes release]; attributes = nil;
	[context didRevertObject: self];
}

- (void) refault
/*" Turns the receiver in to a fault, releasing attribute values. 
	If the reveiver -hasChanges, does nothing. "*/
{
	if (![self hasChanged]) {
		[attributes release]; attributes = nil; // better call -revert?
	}
}

- (BOOL) isFault
/*" Returns wether object attributes need to be fetched. "*/
{
    return attributes==nil;
}

- (BOOL) isDeleted
{
	return [[[self context] deletedObjects] containsObject: self];
}

- (void) willSave
/*" Subclass hook. Called prior to the object's attribute values being saved to the database. "*/
{
}

- (id) valueForUndefinedKey: (NSString*) key
{
	[self willAccessValueForKey: key];
	id result = [self primitiveValueForKey: key];
	[self didAccessValueForKey: key];
	if (NSDebugEnabled && !result) {
		// Check, if this key corresponds to a persistent attribute (slow!):
		if (![[[self class] persistentClassDescription]->attributeDescriptionsByName objectForKey: key]) [super valueForUndefinedKey: key]; // raises exception
	}
	return result;
}

- (OID) currentOid
/*" Private method to be used within the framework only. "*/
{
	return oid;
}


- (OID) oid
/*" Returns the object id for the receiver or NILOID if the object has no context.
	Currently, the defaultContext is always used. "*/
{
	if (!oid) {
		// Create database row and oid:
		OPPersistentObjectContext* context = [self context];
		if (context) {
			OID newOid = [context newDatabaseObjectForObject: self];
			[self setOid: newOid];
		}
	}
    return oid;
}

- (NSString*) objectURLString
{
	return OPURLStringFromOidAndClass([self oid], isa, [[[self context] databaseConnection] name]);
}

- (void) setOid: (OID) theOid
{
	if (oid != theOid) {
		NSAssert(oid==0, @"Object ids can be set only once per instance.");
		oid = theOid;
		[[self context] registerObject: self];
	}
}

- (void) removeAllValuesForKey: (NSString*) key 
/*" Removes all values for key, where key denotes a to-many relationship. "*/
{
	NSEnumerator* relatedObjectsEnumerator = [[self valueForKey: key] objectEnumerator];
	id relatedObject;
	while (relatedObject = [relatedObjectsEnumerator nextObject]) {
		[self removeValue: relatedObject forKey: key];
	}
}

- (void) willDelete
	/*" Called whenever the receiver is marked for deletion. Delete any dependent objects here. Call refault here to immidiately free up attributes. Otherwise they are freed on - saveChanges. Default implementation nullifies all object relations. "*/
{
	OPClassDescription* cd = [[self class] persistentClassDescription];
	
	NSArray* ads = cd->attributeDescriptions;
	int adIndex;
	for (adIndex = [ads count]-1; adIndex>=0; adIndex--) {
	
		OPAttributeDescription* ad  = [ads objectAtIndex: adIndex];
		NSString* irk = [ad inverseRelationshipKey];
		if (irk) {
			NSLog(@"Removing '%@'-relation from %@.", [ad name], self);
			// There is an inverse relationship that needs to have self removed:
			if ([ad isToManyRelationship]) {
				[self removeAllValuesForKey: ad->name];
			} else {
				// Warning: We may fire a fault here - bad!
				[self setValue: nil forKey: ad->name];
			}
		}
	}
}


- (void) willAccessValueForKey: (NSString*) key
{
    [self resolveFault];
	if (key && ![attributes objectForKey: key]) {
		// Try to fetch and cache a relationship:
		id result = [[self context] containerForObject: self
									   relationShipKey: key];
		if (result) {
			// Cache result container in attributes dictionary:
			[attributes setObject: result forKey: key]; 
		}
	}
}


- (void) willChangeValueForKey: (NSString*) key
{
    [self willAccessValueForKey: key]; // not necessary for relationships!
    [[self context] willChangeObject: self];
	[super willChangeValueForKey: key]; // notify observers
}

- (void) willChangeToManyRelationshipForKey: (NSString*) key 
{
	// We do not need to fire a fault - changes are recorded in the OPObjectRelationship object
	[super willChangeValueForKey: key]; // notify observers
}

- (void) didChangeToManyRelationshipForKey: (NSString*) key 
{
	// We do not need to fire a fault - changes are recorded in the OPObjectRelationship object
	[super didChangeValueForKey: key]; // notify observers
}

- (void) didAccessValueForKey: (NSString*) key
{
    [[self context] unlock];
} 

- (void) didChangeValueForKey: (NSString*) key
{
	[self didAccessValueForKey: key];
    [[self context] didChangeObject: self];
	[super didChangeValueForKey: key];
}



- (id) primitiveValueForKey: (NSString*) key
/*" Returns nil, if the receiver is a fault. Call -willAccessValueForKey prior to this method to make sure, the object attributes are in place."*/
{
    id result = [attributes objectForKey: key];
	if (!result) {
		// Test, if we need to fetch a *** todo??
		
	}
	
	
    return result;
}

- (void) setPrimitiveValue: (id) object forKey: (NSString*) key
/*" Passing a nil value is allowed. "*/
{	
	if (object) {
		[attributes setObject: object forKey: key];
	} else {
		[attributes removeObjectForKey: key];
	}
}

//- (void) updateInverseRelationShipValue: (id) value forKey: (NSString*) key isRemove: (BOOL) isRemove
/*" Updates the inverse relationship for the relation denoted by key, i.e. value->self via the inverseRelationshipKey for key. Does nothing, if key does not have an inverse relationship. 
	
	There are four kinds of relationships:
	
     1:1
     1:n
     n:1
     n:m

	"*/
//{
	/*
	OPAttributeDescription* ad = [[isa persistentClassDescription] attributeWithName: key];
	if (!ad) [super setValue: value forUndefinedKey: key]; // throws exception
	
	NSString* inverseRelationshipKey = [ad inverseRelationshipKey];
	if (inverseRelationshipKey) {
		// We need to update an inverse relationship:
		
		// Find out what kind of relationship:
		OPAttributeDescription* iad = [[[ad attributeClass] persistentClassDescription] attributeWithName: key];
		
		id oldValue = [self primitiveValueForKey: key];

		if ([iad isRelationship]) {
			// inverse is a :m relationship
			[oldValue removePrimitiveValue: self forKey: key]; // oldValue may be nil
			[value addPrimitiveValue: self forKey: key]; // value may be nil
		} else {
			NSAssert1(YES, @"Cannot update 1:n relationships. Update inverse %@ relation instead.", inverseRelationshipKey)
			// inverse relationhip is a to-one relationship (e.g. one-to-one)
			id oldSelf = [value valueForKey: inverseRelationshipKey];
			[oldSelf setValue: nil forKey
			
			
			//[oldValue setPrimitiveValue: nil forKey: inverseRelationshipKey]; // oldValue may be nil
			//[value setPrimitiveValue: self forKey: inverseRelationshipKey]; // value may be nil
		}
	}
*/
//}

- (void) setValue: (id) value forUndefinedKey: (NSString*) key
{
	[self willAccessValueForKey: key];
	id oldValue = [self primitiveValueForKey: key];
	[self didAccessValueForKey: key];
	
	if (oldValue != value) {	
		[self willChangeValueForKey: key];
		
		// This is a to-one relationship, because to-many relationships use the add/removeValue methods.
		
		// The inverse relationship might be a to-many relationship. Examine that:	
		OPAttributeDescription* ad = [[[self class] persistentClassDescription] attributeWithName: key];
		if (!ad) [super setValue: value forUndefinedKey: key]; // throws exception, unknown attribute
		
		NSString* inverseKey = [ad inverseRelationshipKey];
		if (inverseKey) {
			// We need to update an inverse relationship:
			
			// Find out what kind of relationship:
			OPAttributeDescription* iad = [[[ad attributeClass] persistentClassDescription] attributeWithName: inverseKey];
			
			if ([iad isToManyRelationship]) {
				// inverse is a to-many relationship, so this is a many-to-one relationship
				[oldValue willChangeValueForKey: inverseKey];
				[oldValue removePrimitiveValue: self forKey: inverseKey]; // oldValue may be nil
				[oldValue didChangeValueForKey: inverseKey];
				[value willChangeValueForKey: inverseKey];
				[value addPrimitiveValue: self forKey: inverseKey]; // value may be nil
				[value didChangeValueForKey: inverseKey];
			} else {
				// inverse is a to-one relationship, so this is a one-to-one relationship
#warning one-to-one (inverse) relationships will create a retain cycle.
				[oldValue setValue: nil forKey: inverseKey];
				id oldSelf = [value objectForKey: inverseKey]; 
				[oldSelf setValue: nil forKey: key];
			}			
		}
		
		[self setPrimitiveValue: value forKey: key]; 
		
		[self didChangeValueForKey: key];
	}
}

- (NSDictionary*) attributeValues
{
	return attributes;
}

- (BOOL) hasChanged
{
	return [[[self context] changedObjects] containsObject: self];
}

/*
- (BOOL) isEqual: (id) other
{
    return isa == [other class] && oid == [other oid];
	// && [self class] == [other class];
}
*/

+ (id) newFromStatement: (sqlite3_stmt*) statement index: (int) index
{
    id result = nil;
    int type = sqlite3_column_type(statement, index);
    //SQLITE_INTEGER, SQLITE_FLOAT, SQLITE_TEXT, SQLITE_BLOB, SQLITE_NULL
    if (type!=SQLITE_NULL) {
		if (type==SQLITE_INTEGER) {
            ROWID rid = sqlite3_column_int64(statement, index);

			if (rid)
				result = [[OPPersistentObjectContext defaultContext] objectForOid: rid 
																		  ofClass: self];
        } else {
            NSLog(@"Warning: Typing Error. Number expected, got sqlite type #%d. Value ignored.", type);
        }
    }
    return result;
}

- (void) dealloc
{
    [[self context] unregisterObject: self];
    [super dealloc];
}


- (NSString*) attributeDescription
/*" Does not call -derscription on other persistent objects to avoid cycles. "*/
{
	NSMutableString* result = nil;
	
	if (attributes) {
		if ([attributes count]) {
			NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
			NSEnumerator* e = [attributes keyEnumerator];
			NSString* key;
			result = [[NSMutableString alloc] initWithString: @"{\n"];
			while (key = [e nextObject]) {
				id value = [attributes objectForKey: key];
				[result appendString: key];
				[result appendString: @": "];
				if ([value isKindOfClass: [NSArray class]]) {
					[result appendString: [NSString stringWithFormat: @"(%d objects)", [value count]]];
				} else {
					[result appendString: [value isKindOfClass: [OPPersistentObject class]] ? [value descriptionIncludingAttributes: NO] : [value description]];
				}
				[result appendString: @";\n"];

			}
			[result appendString: @"}\n"];
 
			[pool release];
		} else {
			result = @"{}";
		}
	}
	//NSLog(@"attrDescr: %@", result);
	return [result autorelease];
}

- (NSString*) descriptionIncludingAttributes: (BOOL) printAttributes
{
	return [NSString stringWithFormat: @"<Persistent %@ (0x%x), oid %llu, attributes: %@>", [self class], self, oid, printAttributes ? [self attributeDescription] : (attributes ? @"{...}" : nil)];
}

- (NSString*) description
{
    return [self descriptionIncludingAttributes: YES];
}

- (void) addPrimitiveValue: (id) value forKey: (NSString*) key
{
	OPFaultingArray* container = [self primitiveValueForKey: key];	
	// container may be nil, if the relationship was never fetched. 
	// This is ok, since addValue:forKey: already updated the relationship object
	// so we'll pick up any changes later.
	[container addObject: value];	
}


- (void) addValue: (id) value forKey: (NSString*) key
{
	// Do we need to check, if value is already contained in array? Could be a performance-Problem?
	// Todo: For to-many relationships, we do not need to fire a fault in order to update its relationship values!

	OPClassDescription* cd = [[self class] persistentClassDescription];
	OPAttributeDescription* ad = [cd attributeWithName: key];
	OPObjectRelationship* r = [[self context] manyToManyRelationshipForAttribute: ad];
	// Check, if it is a many-to-many relation:
	if (r) {
		// Record relationship change in persistent context:
		[r addRelationNamed: key from: self to: value];
	

		// Also update inverse relationship (if any):
		NSString* inverseKey = [ad inverseRelationshipKey];
		if (inverseKey) {
			[value willChangeValueForKey: inverseKey];
			[value addPrimitiveValue: self forKey: inverseKey];
			[value didChangeValueForKey: inverseKey];
		}
		
		// Do we need to check, if value is a fault and not do anything then? Does addPrimitiveValue already handle this?
		if ([self isFault]) {
			return; // we'll pick up the change the next time this fault is fired.
		}
	}
	
	[self willChangeValueForKey: key];
	[self addPrimitiveValue: value forKey: key];
	[self didChangeValueForKey: key];
}

- (void) removePrimitiveValue: (id) value forKey: (NSString*) key
{
	OPFaultingArray* container = [self primitiveValueForKey: key];
	// container may be nil, if the relationship was never fetched. 
	// This is ok, since addValue:forKey: already updated the relationship object
	// so we'll pick up any changes later.
	[container removeObject: value];
}


- (void) removeValue: (id) value forKey: (NSString*) key
{
	OPClassDescription* cd = [[self class] persistentClassDescription];
	OPAttributeDescription* ad = [cd attributeWithName: key];
	OPObjectRelationship* r = [[self context] manyToManyRelationshipForAttribute: ad];
	// Check, if it is a many-to-many relation:
	if (r) {
		// Record relationship change in persistent context:
		[r removeRelationNamed: key from: self to: value];
		

		// Also update inverse relationship (if any):
		NSString* inverseKey = [ad inverseRelationshipKey];
		if (inverseKey) {
			//if ([inverseKey isEqualToString: @"threadsByDate"]) 
			//	NSLog(@"Removing from threadsByDate!");
			[value willChangeValueForKey: inverseKey];
			[value removePrimitiveValue: self forKey: inverseKey];
			[value didChangeValueForKey: inverseKey];
		}
		
		// Do we need to check, if value is a fault and not do anything then? Does removePrimitiveValue already handle this?
		if ([self isFault]) {
			return; // we'll pick up the change the next time this fault is fired.
		}
	}
	
	[value willChangeValueForKey: key];
	[self removePrimitiveValue: value forKey: key];
	[value didChangeValueForKey: key];
	
}

- (NSArray*) validationErrors
/*" Returns an array of validation errors for simple keys attribute keys or nil if no such errors were found. Implement -validate<AttrName>:error: to fill this array. "*/
{
	NSMutableArray* validationErrors = nil;
	OPClassDescription* cd = [isa persistentClassDescription];
	int i = cd->simpleAttributeCount;
	while (--i) {
		OPAttributeDescription* ad = [cd->attributeDescriptions objectAtIndex: i];
		NSError* error = nil;
		NSString* key = ad->name;
		id value = [self valueForKey: key];
		[self validateValue: &value forKey: key error: &error];
		if (error) {
			//id value = [self valueForKey: key];
			if (!validationErrors) validationErrors = [NSMutableArray array];
			[validationErrors addObject: error];
		}
	}
	
	return validationErrors;
}


@end
