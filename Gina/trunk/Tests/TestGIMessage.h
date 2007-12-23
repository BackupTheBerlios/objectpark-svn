//
//  TestGIMessage.h
//  Gina
//
//  Created by Axel Katerbau on 22.12.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>

@class GIMessage;

@interface TestGIMessage : SenTestCase 
{
}

+ (GIMessage *)messageForTest;

@end
