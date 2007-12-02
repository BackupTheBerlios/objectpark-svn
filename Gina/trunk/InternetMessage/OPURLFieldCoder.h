//
//  OPURLFieldCoder.h
//  OPMessageServices
//
//  Created by Dirk Theisen on Thu Jan 24 2002.
//  Copyright (c) 2001 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EDHeaderFieldCoder.h"


@interface OPURLFieldCoder : EDHeaderFieldCoder {
	@private
	NSURL* url;
}

- (NSURL*) url;

@end
