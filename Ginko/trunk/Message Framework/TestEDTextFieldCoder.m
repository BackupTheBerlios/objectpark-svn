//
//  TestEDTextFieldCoder.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 18.02.05.
//  Copyright (c) 2005 __MyCompanyName__. All rights reserved.
//

#import "TestEDTextFieldCoder.h"


@implementation TestEDTextFieldCoder

- (void)setUp
{
}

- (void)tearDown
{
}

- (void)testDecoding 
{
    // This should not crash...
    STAssertNotNil([EDTextFieldCoder stringFromFieldBody: @"=?utf-8?Q?Andr=E9?= Schneider <news.nospam@andre-schneider.net>" withFallback:NO], @"Shouldn't crash");
}

@end
