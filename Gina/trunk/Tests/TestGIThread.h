//
//  TestGIThread.h
//  Gina
//
//  Created by Axel Katerbau on 23.12.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "TestWithPersistence.h"

@interface TestGIThread : TestWithPersistence 
{

}

+ (GIThread *)threadForTest;

@end
