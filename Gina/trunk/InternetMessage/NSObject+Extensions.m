//
//  NSObject+Extensions.m
//  Gina
//
//  Created by Axel Katerbau on 25.12.04.
//  Copyright 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSObject+Extensions.h"

@implementation NSObject (Extensions)

/*" Various extensions to #NSObject. "*/

//---------------------------------------------------------------------------------------
//	RUNTIME CONVENIENCES
//---------------------------------------------------------------------------------------

/*" Raises an #NSInternalInconsistencyException stating that the method must be overriden. "*/

- (volatile void)methodIsAbstract:(SEL)selector
{
    [NSException raise:NSInternalInconsistencyException format: @"*** -[%@ %@]: Abstract definition must be overriden.", NSStringFromClass([self class]), NSStringFromSelector(selector)];
}

- (NSString*) className
{
    return NSStringFromClass([self class]);
}

@end
