//
//  NSError+Extensions.m
//  Gina
//
//  Created by Axel Katerbau on 27.12.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import "NSError+Extensions.h"


@implementation NSError (Extensions)

+ (id) errorWithDomain: (NSString*) domain description: (NSString*) description
{
	NSString* ldescription = NSLocalizedString(description, @"");
	NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys: ldescription, NSLocalizedDescriptionKey, nil, nil];
	return [self errorWithDomain: domain code: 0 userInfo: userInfo];
}

@end
