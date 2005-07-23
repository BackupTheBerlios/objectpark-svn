//
//  OPPersistentObject.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 22.07.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "OPPersistentObject.h"
#import "OPPersistentObjectContext.h"


@implementation OPPersistentObject

+ (NSString*) databaseTableName
/*" Overwrite this in subclass. "*/
{
    return nil; 
}

+ (NSArray*) databaseAttributeNames
/*" Can overwrite this in subclass. Defaults to +[objectAttributeNames]."*/
{
    return [self objectAttributeNames];
}

+ (NSArray*) objectAttributeNames
/*" Overwrite this in subclass. "*/
{
    return nil;
}

- (id) initWithContext: (OPPersistentObjectContext*) context 
                   oid: (OID) anOid
{
    oid = anOid;
    return self;
}

- (OPPersistentObjectContext*) context
{
    return [OPPersistentObjectContext defaultContext]; // simplistic implementation
}

- (BOOL) resolveFault
    /*" Returns YES, if the reciever is not a fault afterwards. "*/
{
    if (attributes==nil) {
        // implement using the default PersistentObjectContext.
        NSLog(@"Warning! Unable to resolve fault object %@", self);
        attributes = [[[self context] persistentValuesForOid: oid
                                                        ofClass: [self class]] retain];
        return attributes != nil;
    }
    return YES;
}

- (void) refault
/*" Turns the reciever in to a fault, releasing attibute values. "*/
{
    [attributes release]; attributes = nil;
}

- (BOOL) isFault
{
    return attributes==nil;
}

- (void) willSave
/*" Subclass hook. Called prior to the object's attribute values being saved to the database. "*/
{
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

- (unsigned) hash
{
    return (unsigned) oid;
}

- (BOOL) isEaual: (id) other
{
    return oid == [other oid];
}

- (void) dealloc
{
    [[self context] unregisterObject: self];
    [super dealloc];
}

@end
