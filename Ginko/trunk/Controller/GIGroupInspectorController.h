//
//  GIGroupInspectorController.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 07.03.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "GIMessageGroup.h"

@interface GIGroupInspectorController : NSObject 
{
    IBOutlet NSWindow *window;
    IBOutlet NSPopUpButton *profileButton;
	IBOutlet NSMatrix *typeRadioButtons;
    GIMessageGroup *group;
}

+ (id)groupInspectorForGroup: (GIMessageGroup*) aGroup;

- (IBAction)switchProfile:(id)sender;
- (IBAction)switchType:(id)sender;

@end
