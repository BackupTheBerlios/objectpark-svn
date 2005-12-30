//
//  GIFulltextIndexJob.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 28.12.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OPPersistence.h"

@interface GIFulltextIndexJob : NSObject 
{
    OPPersistentObjectEnumerator *messagesToIndexEnumerator;
}

+ (void)indexMessages:(OPPersistentObjectEnumerator *)messagesToIndex;
+ (NSString *)jobName;

@end
