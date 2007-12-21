//
//  GIMessageFilter.h
//  Gina
//
//  Created by Axel Katerbau on 21.12.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface GIMessageFilter : NSObject 
{

}

+ (NSMutableArray *)filters;
+ (void)setFilters:(NSMutableArray *)someFilters;
+ (void)saveFilters;

+ (NSArray *)filtersMatchingForMessage:(id)message;

@end
