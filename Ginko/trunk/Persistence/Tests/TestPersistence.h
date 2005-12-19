//
//  OPersistenceTests.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 24.07.05.
//  Copyright 2005 The Objectpark Group. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "OPPersistentObjectContext.h"

#import <SenTestingKit/SenTestingKit.h>


@interface TestPersistence : SenTestCase {
    OPPersistentObjectContext* context;
}


@end
