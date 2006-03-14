//
//  TestGIMessageGroup.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 17.05.05.
//  Copyright (c) 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "TestWithPersistence.h"

@interface TestGIMessageGroup : TestWithPersistence 
{
    unsigned int invalidationCount;
}

@end
