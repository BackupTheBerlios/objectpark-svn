//
//  OPPersistentTestObject.h
//  Gina
//
//  Created by Dirk Theisen on 23.12.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OPPersistentObject.h"
#import "OPPersistentSet.h"

@interface OPPersistentTestObject : OPPersistentObject {
	NSString* name;
	OPPersistentSet* bunch;
}

@property (retain) NSString* name; // simple object attribute, KVO complient

- (NSSet*) bunch; // unordered relation, KVO complient

- (id) initWithName: (NSString*) aName;

@end
