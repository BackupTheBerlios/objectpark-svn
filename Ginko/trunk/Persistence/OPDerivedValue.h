//
//  OPDerivedValue.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 20.07.07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface OPDerivedValue : NSObject {
	long long value;
	NSArray* array;
	NSString* keyPath;
}

- (long long) value;
- (id) initWithArray: (NSArray*) array elementKeyPath: (NSString*) aKeyPath;

@end
