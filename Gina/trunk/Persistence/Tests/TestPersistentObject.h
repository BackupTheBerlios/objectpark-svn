//
//  Test-PersistentObject.h
//  Gina
//
//  Created by Dirk Theisen on 21.12.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "OPPersistentObjectContext.h"
#import "OPPersistentStringDictionary.h"
#import "OPPersistentTestObject.h"


@interface TestPersistentObject : SenTestCase {
	OPPersistentObjectContext* context;
	OPPersistentTestObject* o1;
}

@end
