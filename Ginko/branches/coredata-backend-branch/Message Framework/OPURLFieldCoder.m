//
//  OPURLFieldCoder.m
//  OPMessageServices
//
//  Created by Dirk Theisen on Thu Jan 24 2002.
//  Copyright (c) 2001 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "OPURLFieldCoder.h"
#import "NSString+Extensions.h"
#import "MPWDebug.h"

@implementation OPURLFieldCoder

static NSCharacterSet* backetSet1() {
    static NSCharacterSet* _bracketSet1 = nil;
    if (_bracketSet1==nil)
        _bracketSet1 = [[NSCharacterSet characterSetWithCharactersInString: @"<>"] retain];
    return _bracketSet1;
}

- (id) initWithFieldBody: (NSString*) body
{
    if (self = [super init]) {
        MPWDebugLog(@"%@ stringByRemovingCharactersFromSet: %@  called.",
                    body, backetSet1());
        body = [body stringByRemovingCharactersFromSet: backetSet1()];
        url  = [NSURL URLWithString: body];
    }
    return self;
}

- (NSString*) stringValue {
	return [url resourceSpecifier];
}

- (NSURL*) url {
	return url;
}

@end
