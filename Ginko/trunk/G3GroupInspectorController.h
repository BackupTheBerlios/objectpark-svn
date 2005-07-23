//
//  G3GroupInspectorController.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 07.03.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "G3MessageGroup.h"

@interface G3GroupInspectorController : NSObject 
{
    IBOutlet NSWindow *window;
    IBOutlet NSPopUpButton *profileButton;

    G3MessageGroup *group;
}

+ (id)groupInspectorForGroup:(G3MessageGroup *)aGroup;

- (IBAction)switchProfile:(id)sender;

@end
