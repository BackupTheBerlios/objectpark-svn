//
//  DNDArrayController.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 19.10.06.
//  Copyright 2006 Objectpark Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface DNDArrayController : NSArrayController 
{
	IBOutlet id dndDelegate;
}

- (void)setDndDelegate:(id)aDelegate;

@end
