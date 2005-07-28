//
//  OPPersistentObject.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 22.07.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "OPPersistentObject.h"
#import "OPPersistentObjectContext.h"
#import "OPClassDescription.h"

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

- (id) initWithContext: (OPPersistentObjectContext*) context 
                   oid: (OID) anOid
{
    oid = anOid;
    return self;
}

- (OPPersistentObjectContext*) context
/*" Returns the context for the receiver. Currently, always returns the default context. "*/
{
    return [OPPersistentObjectContext defaultContext]; // simplistic implementation
}

- (BOOL) resolveFault
    /*" Returns YES, if the reciever is not a fault afterwards. "*/
{
    if (attributes==nil) {
        // impjlkjlklement using the default PersistentObjectContext.
        attributes = [[[self context] persistentValuesForObject: self] retain];
        return attributes != nil;
    }
    return YES;
}

- (void) refault
/*" Turns the reciever in to a fault, releasing attibute values. 
	If the reveiver hasChanges, does nothing. "*/
{
	if (![self hasChanged]) {
		[attributes release]; attributes = nil;
	}
}

- (BOOL) isFault
/*" Returns wether object attributes need to be fetched. "*/
{
    return attributes==nil;
}

- (void) willSave
/*" Subclass hook. Called prior to the object's attribute values being saved to the database. "*/
{
}

- (id) valueForUndefinedKey: (NSString*) key
{
	return [self persistentValueForKey: key];
}

- (OID) oid
{
    return oid;
}

- (void) willChangeValueForKey: (NSString*) key
{
    [self resolveFault]; // neccessary?
    [[self context] willChangeObject: self];
}

- (void) willReadValueForKey: (NSString*) key
{
    [[self context] lock];
    [self resolveFault];
}

- (void) didChangeValueForKey: (NSString*) key
{
    [[self context] didChangeObject: self];
}

- (void) didReadValueForKey: (NSString*) key
{
    [[self context] unlock];
}

- (id) persistentValueForKey: (NSString*) key
{
    [self willReadValueForKey: key];
    id result = [attributes objectForKey: key];
    [self didReadValueForKey: key];
    return result;
}

- (void) setPersistentValue: (id) object forKey: (NSString*) key
{
    [self willChangeValueForKey: key];
    [attributes setObject: object forKey: key];
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

- (unsigned) hash
{
    unsigned result = (unsigned) oid;
    //NSLog(@"Hash value of %@ is %u", self, result);
    return result;
}

- (BOOL) isEqual: (id) other
{
    return isa == [other class] && oid == [other oid];
	// && [self class] == [other class];
}

+ (id) newFromStatement: (sqlite3_stmt*) statement index: (int) index
{
    id result = nil;
    int type = sqlite3_column_type(statement, index);
    //SQLITE_INTEGER, SQLITE_FLOAT, SQLITE_TEXT, SQLITE_BLOB, SQLITE_NULL
    if (type!=SQLITE_NULL) {
		if (type==SQLITE_INTEGER) {
            long long value = sqlite3_column_int64(statement, index);
			if (value)
				result = [[OPPersistentObjectContext defaultContext] objectForOid: value 
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

- (NSString*) description
{
    return [NSString stringWithFormat: @"<Persistent %@ (0x%x), oid %llu, attributes: %@>", [self class], self, LIDFromOID(oid), attributes];
}

@end
