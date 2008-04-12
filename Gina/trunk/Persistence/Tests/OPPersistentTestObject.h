//
//  OPPersistentTestObject.h
//  Gina
//
//  Created by Dirk Theisen on 23.12.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OPPersistentObject.h"

@interface OPPersistentTestObject : OPPersistentObject {
	NSString* name;
}

@property (retain) NSString* name;

- (id) initWithName: (NSString*) aName;

@end
