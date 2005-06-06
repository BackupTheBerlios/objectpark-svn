//
//  GIActivityPanelController.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 05.06.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "GIActivityPanelController.h"

@implementation GIActivityPanelController

static GIActivityPanelController *panel = nil;

+ (void)showActivityPanel
{
    if (! panel)
    {
        [[[self alloc] init] autorelease];
    }
    
    [[panel window] orderFront:nil];
}

- (id)init
{
    if (self = [super init])
    {
        [NSBundle loadNibNamed:@"Activity" owner:self];
        
        [self retain]; // balanced in -windowWillClose:
    }
    
    return self;
}

- (NSWindow *)window
{
    return window;
}

- (void)windowWillClose:(NSNotification *)notification 
{
    panel = nil;
    [self autorelease]; // balance self-retaining
}

@end
