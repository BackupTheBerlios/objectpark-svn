//
//  NSError+Extensions.h
//  Gina
//
//  Created by Axel Katerbau on 27.12.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSError (Extensions)

+ (id) errorWithDomain: (NSString*) domain description: (NSString*) description;

@end
