//
//  OPPersistentObject.m
//  Gina
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
#import <Foundation/NSDebug.h>
#import "OPFaultingArray.h"
//#import <objc/message.h>


#define PERSISTENTOBJECT  OPL_DOMAIN  @"PersistentObject"
#define FAULTS            OPL_ASPECT  0x01

/*" This class should be thread-safe. It should synchronize(self) all accesses to the attributes dictionary.
In addition to that, it should synchronize([self context]) all write-accesses to the attributes dictionary. "*/

@implementation OPPersistentObject

- (NSMutableArray*) mutableArrayValueForKey: (NSString*) key
{
	// Expect the mutable array to be changed:
	[[self context] didChangeObject: self];
	return [super mutableArrayValueForKey: key];
}

- (NSMutableArray *)mutableArrayValueForKeyPath:(NSString *)keyPath
{
	// Expect the mutable array to be changed:
	[[self context] didChangeObject: self];
	return [super mutableArrayValueForKeyPath: keyPath];
}

- (NSMutableSet *)mutableSetValueForKeyPath:(NSString *)keyPath
{
	// Expect the mutable array to be changed:
	[[self context] didChangeObject: self];
	return [super mutableSetValueForKeyPath: keyPath];
}


- (NSMutableSet*) mutableSetValueForKey: (NSString*) key
{
	// Expect the mutable array to be changed:
	[[self context] didChangeObject: self];
	return [super mutableSetValueForKey: key];
}

+ (BOOL) cachesAllObjects
/*" Default implementation - returns NO. Subclasses mey override. "*/
{
	return NO;
}

//+ (BOOL) accessInstanceVariablesDirectly
//{
//	return NO; // all setters must be instrumented with -didChangeValueForKey
//}

- (OPPersistentObjectContext*) context
/*" Returns the context for the receiver. Currently, always returns the default context. "*/
{
    return [OPPersistentObjectContext defaultContext]; // simplistic implementation; prepared for multiple contexts.
}

//- (BOOL) resolveFault
///*" Returns YES, if the reciever is resolved afterwards. "*/
//{
//	BOOL result = YES;
//	@synchronized(self) {
//		if (attributes==nil) {
//			NSDictionary* attributesDict = [[[self context] persistentValuesForObject: self] retain];
//			attributes = attributesDict;
//			
//			if (!attributes && oid==0) {
//				attributes = [[NSMutableDictionary alloc] init]; // should set default values here?
//				if (NSDebugEnabled) NSLog(@"Created attribute dictionary for new object %@", self);
//			}
//			result = attributes != nil;
//		}
//	}
//	
//	return result;
//}



- (void) addObserver: (NSObject*) observer forKeyPath: (NSString*) keyPath options: (NSKeyValueObservingOptions) options context: (void*) context
/*" Do not observe yourself => retain cycle. Make sure you pair addObserver with removeObserver to avoid memory leaks. "*/
{
	[self retain];
	//NSLog(@"-addObserver called to %@ instance (keyPath: %@): retaining.", [self class], keyPath);
	[super addObserver: observer forKeyPath: keyPath options: options context: context];
}

- (void) removeObserver: (NSObject*) observer forKeyPath: (NSString*) keyPath
{
	[super removeObserver: observer forKeyPath: keyPath];
	[self release];
}



//- (void) refault
///*" Turns the receiver in to a fault, releasing attribute values. 
//	If the reveiver -hasChanged, this method does nothing. "*/
//{
//	if (![self hasChanged]) {
//		@synchronized(self) {
//			[attributes release]; attributes = nil; // better call -revert?
//		}
//		#warning todo: remove all cached many-to-many relationships on re-fault
//	}
//}
//
//- (BOOL) isFault
///*" Returns wether object attributes need to be fetched. "*/
//{
//    return attributes==nil;
//}

- (BOOL) isDeleted
{
	return [[[self context] deletedObjects] containsObject: self];
}


//- (id) valueForUndefinedKey: (NSString*) key
//{
//	id result = [self primitiveValueForKey: key];
//	[self didAccessValueForKey: key];
////	if (NSDebugEnabled && !result) {
////		// Check, if this key corresponds to a persistent attribute (slow!):
////		if (![[[self class] persistentClassDescription]->attributeDescriptionsByName objectForKey: key]) [super valueForUndefinedKey: key]; // raises exception
////	}
//	return result;
//}

- (OID) currentOID
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
			// Create oid on demand, this means that this is now becoming persistent.
			// Persistent objects unarchived are explicitly given an oid:
			
			OPPersistentObjectContext* context = [self context];
			if (context) {
				[context insertObject: self];
			}
		}
	}
	return oid;
}

- (NSString*) description
{
	return [NSString stringWithFormat: @"<%@: 0x%x, lid %llu>", isa, self, LIDFromOID(oid)];
}

NSString* OPURLStringFromOidAndDatabaseName(OID oid, NSString* databaseName)
{
	NSString* uriString = [[[NSString alloc] initWithFormat: @"x-oppk://%@/%llx", 
							[databaseName stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding], 
							oid] autorelease];
	return uriString;
}

- (void) setContext: (OPPersistentObjectContext*) newContext
{
	// NOP
}

- (NSString*) objectURLString
{
	NSString* databaseName = [[[[self context] databasePath] lastPathComponent] stringByDeletingPathExtension]; // cache this!
	NSString* uriString = [[[NSString alloc] initWithFormat: @"x-oppk-%@://%@/%llx", 
							[databaseName stringByAddingPercentEscapesUsingEncoding: NSISOLatin1StringEncoding], [[self classForCoder] description],
							LIDFromOID([self oid])] autorelease];
	return uriString;
}

- (void) setOID: (OID) theOid
/*" Registers the receiver with the context, if neccessary. "*/
{
	@synchronized(self) {
		if (oid != theOid) {
			NSAssert(oid==0, @"Object ids can be set only once per instance.");
			oid = theOid;
			OPPersistentObjectContext* c = [self context];
			[c registerObject: self];
		}
	}
}

- (id) initWithCoder: (NSCoder*) coder
{
	NSAssert(NO, @"Implement -initWithCoder: for all persistent object subclasses and do not call super on direct subclasses.");
	return nil;
}

- (void) encodeWithCoder: (NSCoder*) coder
{
	NSAssert(NO, @"Implement -encodeWithCoder: for all persistent object subclasses and do not call super on direct subclasses.");
}




- (void) willChangeValueForKey: (NSString*) key
{
	[super willChangeValueForKey: key];
}


- (void) didChangeValueForKey: (NSString*) key
/*" Notify context of the change. "*/
{
	[[self context] didChangeObject: self];
	[super didChangeValueForKey: key];
}

- (void)didChange:(NSKeyValueChange)changeKind valuesAtIndexes:(NSIndexSet *)indexes forKey:(NSString *)key
{
	[[self context] didChangeObject: self];
	[super didChange: changeKind valuesAtIndexes: indexes forKey: key];
}

- (void)didChangeValueForKey:(NSString *)key withSetMutation:(NSKeyValueSetMutationKind)mutationKind usingObjects:(NSSet *)objects
{
	[[self context] didChangeObject: self];
	[super didChangeValueForKey: key withSetMutation: mutationKind usingObjects: objects];
}

- (BOOL) hasUnsavedChanges
{
	return [[[self context] changedObjects] containsObject: self];
}

- (void) delete
/*" Deletes the receiver from the persistent store associated with it's context. Does nothing, if the reciever does not have a context or has never been stored persistently. "*/
{	
	if (oid) {
		[[self context] deleteObject: self];
	}
	//[self refault]; // free attribute resources
}


//- (id) primitiveValueForKey: (NSString*) key
///*" Fills the attributes dictionary, if necessary, i.e. fires the fault. The result is autoreleased in the calling thread. "*/
//{
//	id result;
//	
//	@synchronized(self) {
//		[self xwillAccessValueForKey: key]; // fire fault, make sure the attribute values exist.
//		result = [[attributes objectForKey: key] retain];
//	}	
//	return [result autorelease]; // needed to be thread-safe?
//}
//
//- (void) setPrimitiveValue: (id) object forKey: (NSString*) key
///*" Passing a nil value is allowed and removes the respective value. "*/
//{	
//	
//#warning Stop resolving faults for deleted objects!
//	@synchronized([self context]) {
//		@synchronized(self) {
//			[self xwillAccessValueForKey: key];
//
//			if (object) {
//				[attributes setObject: object forKey: key];
//			} else {
//				[attributes removeObjectForKey: key];
//			}
//		}
//	}
//}

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
	if (![self canPersist]) return [super setValue: value forUndefinedKey: key];
	// Do not allow setting values during e.g. a commit:
	@synchronized([self context]) {
		if ([key hasSuffix: @"OID"]) {

		} else {
			if ([value canPersist]) {
				[self willChangeValueForKey: key];
				NSString* oidKey = [[NSString alloc] initWithFormat: @"%@OID", key];
				[self setValue: [NSNumber numberWithUnsignedLongLong: [value oid]] forKey: oidKey]; // optimize somehow
				[oidKey release];
				[self didChangeValueForKey: key];
				return;
			}
		}
		[super setValue: value forUndefinedKey: key];
	}
}

- (BOOL) hasChanged
{
	return [[[self context] changedObjects] containsObject: self];
}

- (id) valueForUndefinedKey: (NSString*) key
{
	if (! [key hasSuffix: @"OID"]) {
		// optimize by temporarily using char* for the oidKey below:
		NSString* oidKey = [[NSString alloc] initWithFormat: @"%@OID", key];
		NSNumber* oidNumber = [self valueForKey: oidKey];
		OID resultOID = [oidNumber unsignedLongLongValue];
		id result = [[self context] objectForOID: resultOID];
		[oidKey release];
		return result;
	}
	return [super valueForUndefinedKey: key];
}



- (void) dealloc
{
    [[self context] unregisterObject: self];
    [super dealloc];
}


//- (NSString*) attributeDescription
///*" Does not call -derscription on other persistent objects to avoid cycles. "*/
//{
//	NSMutableString* result = nil;
//	
//	if (attributes) {
//		if ([attributes count]) {
//			NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
//			NSEnumerator* e = [attributes keyEnumerator];
//			NSString* key;
//			result = [[NSMutableString alloc] initWithString: @"{\n"];
//			while (key = [e nextObject]) {
//				id value = [attributes objectForKey: key];
//				[result appendString: key];
//				[result appendString: @": "];
//				if ([value isKindOfClass: [NSArray class]]) {
//					[result appendString: [NSString stringWithFormat: @"(%d objects)", [value count]]];
//				} else {
//					[result appendString: [value isKindOfClass: [OPPersistentObject class]] ? [value descriptionIncludingAttributes: NO] : [value description]];
//				}
//				[result appendString: @";\n"];
//
//			}
//			[result appendString: @"}\n"];
// 
//			[pool release];
//		} else {
//			result = @"{}";
//		}
//	}
//	//NSLog(@"attrDescr: %@", result);
//	return [result autorelease];
//}

//- (NSString*) descriptionIncludingAttributes: (BOOL) printAttributes
//{
//	return [NSString stringWithFormat: @"<Persistent %@ (0x%x), oid %llu, attributes: %@>", [self class], self, oid, printAttributes ? [self attributeDescription] : (attributes ? @"{...}" : nil)];
//}

//- (NSString*) description
//{
//    return [self descriptionIncludingAttributes: YES];
//}

//- (void) addPrimitiveValue: (id) value forKey: (NSString*) key
//{
//	@synchronized([self context]) {
//		id container = [self primitiveValueForKey: key];	
//		[container addObject: value]; // thread-safe
//	}
//}
//
//
//- (void) addValue: (id) value forKey: (NSString*) key
//{
//	[self willChangeValueForKey: key];
//	[self addPrimitiveValue: value forKey: key];
//	[self didAddValueForKey: key];
//}
//
//- (void) removePrimitiveValue: (id) value forKey: (NSString*) key
//{
//	id container = [self primitiveValueForKey: key]; // fires fault
//	[container removeObject: value]; // thread-safe
//}
//
//- (void) removeValue: (id) object forKey: (NSString*) key
//{
//	[self willChangeValueForKey: key];
//	[self removePrimitiveValue: value forKey: key];
//	[self didAddValueForKey: key];
//}

- (BOOL) accessInstanceVariablesDirectly
{
	return NO;
}
 
+ (BOOL) canPersist
{
	return YES;
}

- (BOOL) canPersist
{
	return YES;
}

- (BOOL) isEqual: (id) other
{
	if (![other respondsToSelector: @selector(oid)]) {
		return NO;
	}
		  
	return [self oid] == [other oid];
}

- (NSUInteger) hash
{
	return (NSUInteger)(LIDFromOID([self oid]) % NSUIntegerMax);
}


//- (void) removeValue: (id) value forKey: (NSString*) key
//{
//	@synchronized([self context]) {
//		@synchronized(self) {
//			if ([[self valueForKey: key] containsObject: value]) { // check only necessary for n:m relations?
//				
//				OPClassDescription* cd = [[self class] persistentClassDescription];
//				OPAttributeDescription* ad = [cd attributeWithName: key];
//				OPObjectRelationship* r = [[self context] manyToManyRelationshipForAttribute: ad];
//				NSString* inverseKey = [ad inverseRelationshipKey];
//				
//				// Check, if it is a many-to-many relation:
//				if (r) {
//					// Record relationship change in persistent context:
//					[r removeRelationNamed: key from: self to: value];
//					
//					if (inverseKey) {
//						// Also update inverse relationship (if any):
//						[value willChangeValueForKey: inverseKey];
//						if ([[value attributeValues] objectForKey: inverseKey]) {
//							[value removePrimitiveValue: self forKey: inverseKey];
//						}
//						[value didRemoveValueForKey: inverseKey];
//					}
//					
//					// If we did not yet fire the relationship, skip removing the primitive value:
//					if (![attributes objectForKey: key]) {
//						// The relationship has not fired yet:
//						[self willChangeValueForKey: key];
//						[self didRemoveValueForKey: key];
//						return; // we'll pick up the change the next time this fault is fired.
//					}
//					
//				} else {
//					// n:1 relationship
//					if (inverseKey) {
//						// Eager updates are necessary for now:
//						[value willChangeValueForKey: inverseKey];
//						[value setPrimitiveValue: nil forKey: inverseKey];
//						[value didChangeValueForKey: inverseKey];
//					}
//				}
//				
//				// Do we need to do this, when self is a fault?		
//				[self willChangeValueForKey: key];
//				[self removePrimitiveValue: value forKey: key]; // index already calculated above - optimize?
//				[self didRemoveValueForKey: key];
//			}
//		}
//	}
//}

//- (NSArray*) validationErrors
///*" Returns an array of validation errors for simple keys attribute keys or nil if no such errors were found. Implement -validate<AttrName>:error: to fill this array. "*/
//{
//	NSMutableArray* validationErrors = nil;
//	OPClassDescription* cd = [isa persistentClassDescription];
//	int i = cd->simpleAttributeCount;
//	
//	@synchronized(self) {
//		while (--i) {
//			OPAttributeDescription* ad = [cd->attributeDescriptions objectAtIndex: i];
//			NSError* error = nil;
//			NSString* key = ad->name;
//			id value = [self valueForKey: key];
//			[self validateValue: &value forKey: key error: &error];
//			if (error) {
//				//id value = [self valueForKey: key];
//				if (!validationErrors) validationErrors = [NSMutableArray array];
//				[validationErrors addObject: error];
//			}
//		} 
//	}
//	return validationErrors;
//}

- (void) turnIntoFault
{
	Class faultClass = [OPPersistentObjectFault class];
	isa = faultClass;
}

- (id) initFaultWithContext: (OPPersistentObjectContext*) context oid: (OID) anOID
{
	[self turnIntoFault];
	[self setOID: anOID];
	return self;
}

- (BOOL) resolveFault
{
	return YES;
}


//- (void) awakeAfterUsingCoder: (NSCoder*) aCoder
//{
//	if ([aCoder isKindOfClass: [OPKeyedUnarchiver class]]) {
////		 [self turnIntoFault];
//	}
//}

@end

@implementation OPPersistentObjectFault : OPPersistentObject

- (BOOL) resolveFault
{
	Class theClass = [[self context] classForCID: CIDFromOID(self.currentOID)];
	isa = theClass;
	BOOL ok = [[self context] unarchiveObject: self forOID: self.currentOID];
	return ok;
}


//static IMP nsObjectPerform = NULL;
static Class OPPersistentObjectFaultClass = Nil;

+ (void) initialize {
    if (! OPPersistentObjectFaultClass) {
        //Class NSObjectClass = objc_getClass("NSObject");
        OPPersistentObjectFaultClass  = self;
        //nsObjectPerform = [NSObjectClass instanceMethodForSelector: @selector(performv::)];
		
        [super initialize];
        //NSLog(@"%@ class initialized.\n", self);
    }
}


+ allocWithZone: (NSZone*) aZone 
{
    NSParameterAssert(NO);
    return nil;
}

+ (id) alloc
{
	NSParameterAssert(NO);
    return nil;
}

- (Class) class
{
	Class theClass = [[self context] classForCID: CIDFromOID(self.oid)];
	return theClass;
}

+ (BOOL) isFault
{
	return YES;	
}


- (BOOL) conformsToProtocol: (id) fp8
{
	NSLog(@"oops! implement!");
	return YES;
}

- (id) methodSignatureForSelector: (SEL) aSelector
{
	return [[self class] instanceMethodSignatureForSelector: (SEL) aSelector];
}

- (BOOL) respondsToSelector: (SEL) aSelector
{
	return [[self class] instancesRespondToSelector: aSelector];
}

- (void) forwardInvocation: (NSInvocation*) invocation
{
	NSLog(@"Firing %@ after call to '%@'.", isa, NSStringFromSelector([invocation selector]));

	BOOL ok = [self resolveFault];
	
	if (ok) [invocation invokeWithTarget: self];
}

- (void) setValue: (id) value forKey: (NSString*) key
{
	// For some reason, faults do not fire automatically:
	NSLog(@"Firing %@ after call to 'setValue:forKey: %@'.", isa, key);
	BOOL ok = [self resolveFault];
    if (ok) [self setValue: value forKey: key];
}


- (id) valueForKey: (NSString*) key 
{
    // For some reason, faults do not fire automatically:
	NSLog(@"Firing %@ after call to 'valueForKey: %@'.", isa, key);
	BOOL ok = [self resolveFault];
    return ok ? [self valueForKey: key] : nil;
}

//- (void) addObserver: (NSObject*) observer forKeyPath: (NSString*) keyPath options: (NSKeyValueObservingOptions) options context: (void*) context
//{
////	if ([[self "class"] automaticallyNotifiesObserversForKey:(NSString *)key]) {
////		
////	}
////])
//	NSLog(@"Firing %@ after call to 'addObserver:forKeyPath: %@'.", isa, keyPath);
//	BOOL ok = [self resolveFault];
//    if (ok) [self addObserver: observer forKeyPath: keyPath options: options context: context];
//}

//- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel
//{
//	
//}

//-  forward: (SEL) sel : (marg_list) args 
//{
//    //NSLog(@"Firing %@ triggered by a call to \"%s\" ... ", NSStringFromClass(selfClass), SELNAME(sel));
//
//	
//	[self resolveFault];
//    //return nsObjectPerform(self, _cmd, sel, args);
//	[self performv: _cmd];
//}

@end


@implementation NSObject (OPPersistence)

+ (BOOL) canPersist
{
	return NO;
}

- (BOOL) canPersist
{
	return NO;
}


- (BOOL) isPlistMemberClass
{
	return NO;
}

- (void) willSave
/*" Subclass hook. Called prior to the object's attribute values being saved to the database. "*/
{
}


- (void) willDelete
/*" Subclass hook. Called whenever the receiver is marked for deletion. Delete any dependent objects here. After this call, -refault will free all attribute values. Default implementation does nothing. "*/
{
}

- (void) willRevert
{
	// subclass hook
}


@end

@implementation NSString (OPPersistence)

- (BOOL) isPlistMemberClass
{
	return YES;
}

@end

@implementation NSData (OPPersistence)

- (BOOL) isPlistMemberClass
{
	return YES;
}

@end

