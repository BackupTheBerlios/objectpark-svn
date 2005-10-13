//
//  OPersistenceTests.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 24.07.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "OPPersistentObjectContext.h"

#import <SenTestingKit/SenTestingKit.h>


@interface TestPersistence : SenTestCase {
    OPPersistentObjectContext* context;
}


@end
