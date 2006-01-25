//
//  GIFulltextSearchPane.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 22.01.06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "GIFulltextSearchPane.h"
#import "GIFulltextIndex.h"

@implementation GIFulltextSearchPane

- (IBAction)resetFulltextIndex:(id)sender
{
    [GIFulltextIndex resetIndex];
}

@end
