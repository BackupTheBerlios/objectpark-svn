//
//  GIFilterArrayController.h
//  Gina
//
//  Created by Axel Katerbau on 14.12.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface GIFilterArrayController : NSArrayController 
{
	IBOutlet NSTableView *tableView;
}

- (IBAction)clone:(id)sender;

@end
