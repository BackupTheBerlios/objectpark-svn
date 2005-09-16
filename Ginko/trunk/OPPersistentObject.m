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

#import "GIThread.h"

@implementation OPPersistentObject


+ (void) initialize
{

}

+ (NSString*) persistentAttributesPlist
{
	return @"{}";
}

+ (NSString*) databaseTableName
/*" Overwrite this in subclass. Default implementation returns class name. "*/
{
    return NSStringFromClass(self); 
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
	[context willChangeObject: self];
	NSParameterAssert([self context]==nil);
	attributes = [[NSMutableDictionary alloc] init]; // should set default values here?
	NSLog(@"Created attribute dictionary for object %@");
	[context didChangeObject: self];
}

- (id) initFaultWithContext: (OPPersistentObjectContext*) context 
						oid: (OID) anOid
{
	NSParameterAssert(anOid>0);
	// Set the context here in the future
	[self setOid: anOid];
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
    }
	return attributes != nil;
}

- (void) revert
{
/*" Turns the receiver in to a fault, releasing attribute values. 
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

- (NSURL*) objectURL
{
	return OPURLFromOidAndClass([self oid], isa);
}

- (void) setOid: (OID) theOid
{
	if (oid != theOid) {
		NSAssert(oid==0, @"Object ids can be set only once per instance.");
		oid = theOid;
		[[self context] registerObject: self];
	}
}

- (void) willDelete
	/*" Called whenever the receiver is marked for deletion. Delete any dependent objects here. Call refault here to immidiately free up attributes. Otherwise they are freed on - saveChanges. "*/
{
	
}


- (void) willChangeValueForKey: (NSString*) key
{
    [self resolveFault]; // neccessary?
    [[self context] willChangeObject: self];
}

- (void) willAccessValueForKey: (NSString*) key
{
    [[self context] lock];
    [self resolveFault];
}

- (void) didChangeValueForKey: (NSString*) key
{
    [[self context] didChangeObject: self];
}

- (void) didAccessValueForKey: (NSString*) key
{
    [[self context] unlock];
} 

- (id) primitiveValueForKey: (NSString*) key
{
    id result = [attributes objectForKey: key];
	if (!result) {
		result = [[self context] containerForObject: self
									relationShipKey: key];
		
		// Cache result container in attributes dictionary:
		if (result) [attributes setObject: result forKey: key]; 
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

- (void) setValue: (id) value forUndefinedKey: (NSString*) key
{
	[self willChangeValueForKey: key];
	[self setPrimitiveValue: value forKey: key];
	[self didChangeValueForKey: key];
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

- (void) addValue: (id) value forKey: (NSString*) key
{
	OPFaultingArray* container = [self primitiveValueForKey: key];
	// Do we need to check, if value is already contained in array? Could be a performance-Problem?
#warning Record relationship change in persistent context somehow.
#warning Also update inverse relationship (if any)
	
	[container addObject: value];	
}

- (void) removeValue: (id) value forKey: (NSString*) key
{
	OPFaultingArray* container = [self primitiveValueForKey: key];
#warning Record relationship change in persistent context somehow.
#warning Also update inverse relationship.
	[container removeObject: value];
}


@end
