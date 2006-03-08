//
//  $Id:NSThread+OPThreadNames.h$
//  OPDebug
//
//  Created by Jörg Westheide on 24.11.2005.
//  Copyright 2005 Objectpark.org. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSThread (OPThreadNames)

- (void) setName:(NSString*) aName;
- (NSString*) name;

@end
