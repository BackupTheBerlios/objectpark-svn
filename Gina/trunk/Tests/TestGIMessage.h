//
//  TestGIMessage.h
//  Gina
//
//  Created by Axel Katerbau on 22.12.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "TestWithPersistence.h"

@class GIMessage;

@interface TestGIMessage : TestWithPersistence 
{
}

+ (GIMessage *)messageForTest;

@end
