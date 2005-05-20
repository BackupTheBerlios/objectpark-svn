//
//  GroupController.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on Fri Jul 23 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "G3Message.h"
#import "G3MessageGroup.h"
#import "G3Thread.h"

//#import <OPMessageServices/OPMessageServices.h>


@interface GroupController : NSObject {

    IBOutlet NSTableView* tableView;
    IBOutlet NSTextView* messageBodyView;
    IBOutlet NSTabView* tabView;
    IBOutlet id testField;
    G3Message* displayedMessage;
    NSMutableArray* threads;
    G3MessageGroup* group;
}

+ (id) controllerWithGroup: (G3MessageGroup*) groupName;

- (IBAction) toggleDisplay: (id) sender;

@end
