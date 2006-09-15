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
//  This library is used commercially whenever the library or work depending on this library
//  is charged for more than the price for shipping and handling.
//

#import "OPPersistentObject.h"
#import "OPPersistentObjectContext.h"
#import "OPClassDescription.h"
#import <Foundation/NSDebug.h>
#import "OPObjectRelationship.h"
#import "GIThread.h"


#define PERSISTENTOBJECT  OPL_DOMAIN  @"PersistentObject"
#define FAULTS            OPL_ASPECT  0x01

/*" This class should be thread-safe. It should synchronize(self) all accesses to the attributes dictionary.
In addition to that, it should synchronize([self context]) all write-accesses to the attributes dictionary. "*/

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
/*" Index is 1-based as in sqlite. "*/
{
	sqlite3_bind_int64(statement, index, [self oid]);
}

- (void) insertIntoContext: (OPPersistentObjectContext*) context
{
	OPPersistentObjectContext* previousContext = [self context];
	NSParameterAssert(previousContext == context || previousContext == nil);
	
	NSParameterAssert(oid==0);
	// Create attributes dictionary as necessary
	if (!attributes) {
		//NSLog(@"Creating attribute dictionary for object %@", self);
		attributes = [[NSMutableDictionary alloc] init]; // should we set default values here?
	}
	//[context willChangeObject: self];
	[context insertObject: self];
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
/*" Returns YES, if the reciever is resolved afterwards. "*/
{
	BOOL result = YES;
	@synchronized(self) {
		if (attributes==nil) {
			NSDictionary* attributesDict = [[[self context] persistentValuesForObject: self] retain];
			attributes = attributesDict;
			
			if (!attributes && oid==0) {
				attributes = [[NSMutableDictionary alloc] init]; // should set default values here?
				OPDebugLog(PERSISTENTOBJECT, FAULTS, @"Created attribute dictionary for new object %@", self);
			}
			result = attributes != nil;
		}
	}
	
	return result;
}

- (void) revert
/*" Turns the receiver back into a fault, releasing attribute values. 
	Changes done since the last -saveChanges are lost. "*/
{
	id context = [self context];
	
	[context willRevertObject: self];
	@synchronized(self) {
		[attributes release]; attributes = nil;
	}
	
	[context didRevertObject: self];
}

- (void) refault
/*" Turns the receiver in to a fault, releasing attribute values. 
	If the reveiver -hasChanged, this method does nothing. "*/
{
	if (![self hasChanged]) {
		@synchronized(self) {
			[attributes release]; attributes = nil; // better call -revert?
		}
		#warning todo: remove all cached many-to-many relationships on re-fault
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
		@synchronized(self) {
			// Create database row and oid:
			OPPersistentObjectContext* context = [self context];
			if (context) {
				OID newOid = [context newDatabaseObjectForObject: self];
				[self setOid: newOid];
			}
		}
	}
	return oid;
}

- (NSString*) objectURLString
{
	return OPURLStringFromOidAndClass([self oid], [self class], [[[self context] databaseConnection] name]);
}

- (void) setOid: (OID) theOid
/*" Registers the receiver with the context, if neccessary. "*/
{
	@synchronized(self) {
		if (oid != theOid) {
			NSAssert(oid==0, @"Object ids can be set only once per instance.");
			*((OID*)&oid) = theOid;
			[[self context] registerObject: self];
		}
	}
}

- (void) removeAllValuesForKey: (NSString*) key 
/*" Removes all values for key, where key denotes a to-many relationship. "*/
{
	NSArray* values = [self valueForKey: key];
	id relatedObject;
	while (relatedObject = [values lastObject]) {
		[self removeValue: relatedObject forKey: key];
	}
}

- (void) willDelete
	/*" Called whenever the receiver is marked for deletion. Delete any dependent objects here. After this calll, -refault will free all attribute values. Default implementation nullifies all object relations. "*/
{
	OPClassDescription* cd = [[self class] persistentClassDescription];
		
	NSArray* ads = cd->attributeDescriptions;
	int adIndex;
	for (adIndex = [ads count]-1; adIndex>=0; adIndex--) {
	
		OPAttributeDescription* ad  = [ads objectAtIndex: adIndex];
		NSString* irk = [ad inverseRelationshipKey];
		if (irk) {
			//NSLog(@"Removing '%@'-relation from %@.", [ad name], self);
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

/*
- (void) willChangeValueForKey: (NSString*) key
{
    //[[self context] willChangeObject: self];
	[super willChangeValueForKey: key]; // notify observers
}
*/

- (void) didAccessValueForKey: (NSString*) key
{
} 

- (void) willAccessValueForKey: (NSString*) key
{
}

- (void) didRemoveValueForKey: (NSString*) key
/*" Same as didChangeValueForKey: but for to-many removals. Does not mark the the object itself as dirty. "*/
{
	// currently the same as didAddValueForKey:
	[self didAddValueForKey: key]; 
}

- (void) didAddValueForKey: (NSString*) key
/*" Same as didChangeValueForKey: but for to-many additions. Does not mark the the object itself as dirty. "*/
{
	[self didAccessValueForKey: key];
	// All To-Many redlationship changes are recorded elsewhere
	// if (NSDebugEnabled) NSLog(@"Skipped dirty-setting for add/remove-%@.", key);
	[self didChangeValueForKey: key];
}

- (void) didChangeValueForKey: (NSString*) key
/*" Call respaective didAdd/Remove methods for to-many relationships fror efficiency. "*/
{
	[self didAccessValueForKey: key];
	[[self context] didChangeObject: self];
	[super didChangeValueForKey: key];
}

- (void) delete
/*" Deletes the receiver from the persistent store associated with it's context. Does nothing, if the reciever does not have a context or has never been stored persistently. "*/
{
	if (oid) {
		[[self context] shouldDeleteObject: self];
	}
	[self refault]; // free attribute resources
}

- (void) xwillAccessValueForKey: (NSString*) key

{
	if (!attributes) [[self context] willFireFault: self forKey: key]; // statistics - not elegant	
	
    BOOL resolved = [self resolveFault];
	if (!resolved) {
		NSLog(@"Faulting problem: %@ with oid %llu not in the database!?", [self class], oid);
	}
				
	if (key && ![attributes objectForKey: key]) {
		// Try to fetch and cache a relationship:
		id result = [[self context] containerForObject: self
									   relationShipKey: key];
		if (result) {
			// Cache result container in attributes dictionary:
			@synchronized(self) {
				[attributes setObject: result forKey: key]; 
			}
		}
	}
}

- (id) primitiveValueForKey: (NSString*) key
/*" Fills the attributes dictionary, if necessary, i.e. fires the fault. The result is autoreleased in the calling thread. "*/
{
	id result;
	
	@synchronized(self) {
		[self xwillAccessValueForKey: key]; // fire fault, make sure the attribute values exist.
		result = [[attributes objectForKey: key] retain];
	}	
	return [result autorelease]; // needed to be thread-safe?
}

- (void) setPrimitiveValue: (id) object forKey: (NSString*) key
/*" Passing a nil value is allowed and removes the respective value. "*/
{	
	
#warning Stop resolving faults for deleted objects!
	@synchronized([self context]) {
		@synchronized(self) {
			[self xwillAccessValueForKey: key];

			if (object) {
				[attributes setObject: object forKey: key];
			} else {
				[attributes removeObjectForKey: key];
			}
		}
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
	// Do not allow setting values during e.g. a commit:
	@synchronized([self context]) {
		id oldValue = [self primitiveValueForKey: key];
		
		if (![oldValue isEqual: value]) {	
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
					[oldValue didRemoveValueForKey: inverseKey];
					[value willChangeValueForKey: inverseKey];
					[value addPrimitiveValue: self forKey: inverseKey]; // value may be nil
					[value didAddValueForKey: inverseKey];
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
}

- (NSDictionary*) attributeValues
/*" For internal use only! @synchronize the receiver while accessing values of the dictionary returned. "*/
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
	@synchronized([self context]) {
		OPFaultingArray* container = [self primitiveValueForKey: key];	
		[container addObject: value]; // thread-safe
	}
}


- (void) addValue: (id) value forKey: (NSString*) key
{
	// Do we need to check, if value is already contained in array? Could be a performance-Problem?
	// Todo: For to-many relationships, we do not need to fire a fault in order to update its relationship values!
	
	@synchronized([self context]) {
		@synchronized(self) {
			@synchronized(value) {
				if (![[self valueForKey: key] containsObject: value]) {
					OPClassDescription* cd = [[self class] persistentClassDescription];
					OPAttributeDescription* ad = [cd attributeWithName: key];
					OPObjectRelationship* r = [[self context] manyToManyRelationshipForAttribute: ad];
					NSString* inverseKey = [ad inverseRelationshipKey];
					
					// Check, if it is a many-to-many relation:
					if (r) {
						// Record relationship change in persistent context:
						[r addRelationNamed: key from: self to: value];
						
						// Also update inverse relationship (if any):
						if (inverseKey) {
							[value willChangeValueForKey: inverseKey];
							if ([[value attributeValues] objectForKey: inverseKey]) {
								// Firing the relationship will add self via r later otherwise.
								[value addPrimitiveValue: self forKey: inverseKey];
							}
							[value didAddValueForKey: inverseKey];
						}
						
						if (![attributes objectForKey: key]) {
							// The relationship has not fired yet:
							[self willChangeValueForKey: key];
							[self didAddValueForKey: key];
							return; // we'll pick up the change the next time this fault is fired.
						}
						
					} else {
						if (inverseKey) {
							// many-to-one relationship
							id oldIValue = [value valueForKey: inverseKey];
							
							if (oldIValue) {
								[oldIValue removeValue: value forKey: key]; // remove from inverse inverse relationship (if any). This might fire oldIValue. gr2mpf
							}
							
							[value willChangeValueForKey: inverseKey];
							[value setPrimitiveValue: self forKey: inverseKey];
							[value didChangeValueForKey: inverseKey];
						}
					}
					[self willChangeValueForKey: key];
					[self addPrimitiveValue: value forKey: key];
					[self didAddValueForKey: key];
				} else {
					
					NSLog(@"Warning! Try to add %@ to existing %@-relationship of %@!", value, key, self);
				}
			}
		}
	}
}

- (void) removePrimitiveValue: (id) value forKey: (NSString*) key
{
	OPFaultingArray* container = [self primitiveValueForKey: key]; // fires fault
	[container removeObject: value]; // thread-safe
}

- (id) transientValueForKey: (NSString*) key
{
	//[self resolveFault];
	id result;
	
	@synchronized(self) {
		//result = [attributes objectForKey: key];
		if (NSDebugEnabled) {
			if ([[[self class] persistentClassDescription]->attributeDescriptionsByName objectForKey: key]) 
				[super valueForUndefinedKey: key]; // raises exception, not a transient value
		}
		result = [self primitiveValueForKey: key];
	}
	return result;
}

- (void) setTransientValue: (id) value forKey: (NSString*) key
/*" Do not set values for persistent keys! "*/
{
	@synchronized(self) {
		if (NSDebugEnabled) {
			if ([[[self class] persistentClassDescription]->attributeDescriptionsByName objectForKey: key]) 
				[super valueForUndefinedKey: key]; // raises exception
		}
#warning todo: add key-value-observing for transient values.
		[self xwillAccessValueForKey: key];
		
		if (value) {
			[attributes setObject: value forKey: key];
		} else {
			[attributes removeObjectForKey: key];
		}
	}
}


- (void) removeValue: (id) value forKey: (NSString*) key
{
	@synchronized([self context]) {
		@synchronized(self) {
			if ([[self valueForKey: key] containsObject: value]) { // check only necessary for n:m relations?
				
				OPClassDescription* cd = [[self class] persistentClassDescription];
				OPAttributeDescription* ad = [cd attributeWithName: key];
				OPObjectRelationship* r = [[self context] manyToManyRelationshipForAttribute: ad];
				NSString* inverseKey = [ad inverseRelationshipKey];
				
				// Check, if it is a many-to-many relation:
				if (r) {
					// Record relationship change in persistent context:
					[r removeRelationNamed: key from: self to: value];
					
					if (inverseKey) {
						// Also update inverse relationship (if any):
						[value willChangeValueForKey: inverseKey];
						if ([[value attributeValues] objectForKey: inverseKey]) {
							[value removePrimitiveValue: self forKey: inverseKey];
						}
						[value didRemoveValueForKey: inverseKey];
					}
					
					// If we did not yet fire the relationship, skip removing the primitive value:
					if (![attributes objectForKey: key]) {
						// The relationship has not fired yet:
						[self willChangeValueForKey: key];
						[self didRemoveValueForKey: key];
						return; // we'll pick up the change the next time this fault is fired.
					}
					
				} else {
					// n:1 relationship
					if (inverseKey) {
						// Eager updates are necessary for now:
						[value willChangeValueForKey: inverseKey];
						[value setPrimitiveValue: nil forKey: inverseKey];
						[value didChangeValueForKey: inverseKey];
					}
				}
				
				// Do we need to do this, when self is a fault?		
				[self willChangeValueForKey: key];
				[self removePrimitiveValue: value forKey: key]; // index already calculated above - optimize?
				[self didRemoveValueForKey: key];
			}
		}
	}
}

- (NSArray*) validationErrors
/*" Returns an array of validation errors for simple keys attribute keys or nil if no such errors were found. Implement -validate<AttrName>:error: to fill this array. "*/
{
	NSMutableArray* validationErrors = nil;
	OPClassDescription* cd = [isa persistentClassDescription];
	int i = cd->simpleAttributeCount;
	
	@synchronized(self) {
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
	}
	return validationErrors;
}


@end
