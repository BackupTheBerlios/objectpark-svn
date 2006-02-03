//
//  TestWithPersistence.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 03.02.06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "OPPersistentObjectContext.h"

@interface TestWithPersistence : SenTestCase 
{
    OPPersistentObjectContext *context;
}

@end
