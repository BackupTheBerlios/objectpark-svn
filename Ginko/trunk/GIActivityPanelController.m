//
//  GIActivityPanelController.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 05.06.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "GIActivityPanelController.h"
#import "OPJobs.h"

@implementation GIActivityPanelController

static GIActivityPanelController *panel = nil;
static NSString *GIActivityPanelNeedsUpdateNotification = @"GIActivityPanelNeedsUpdateNotification";

- (void)updateData:(NSNotification *)aNotification
{
    [jobIds autorelease];
    jobIds = [[OPJobs runningJobs] retain];
    
    [tableView reloadData];
}

- (void)dataChanged:(NSNotification *)aNotification
{
    NSNotification *notification = [NSNotification notificationWithName:GIActivityPanelNeedsUpdateNotification object:self];
    [[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostWhenIdle coalesceMask:NSNotificationCoalescingOnName | NSNotificationCoalescingOnSender forModes:nil];
}

+ (void)showActivityPanel
{
    if (! panel)
    {
        panel = [[[self alloc] init] autorelease];
    }
    
    [[panel window] orderFront:nil];
    [panel dataChanged:nil];
}

- (id)init
{
    if (self = [super init])
    {
        [NSBundle loadNibNamed:@"Activity" owner:self];
        
        [self retain]; // balanced in -windowWillClose:
        
        // register for notifications:
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        
        [center addObserver:self selector:@selector(updateData:) name:GIActivityPanelNeedsUpdateNotification object:nil];
        [center addObserver:self selector:@selector(dataChanged:) name:OPJobDidFinishNotification object:nil];
        [center addObserver:self selector:@selector(dataChanged:) name:OPJobDidSetProgressInfoNotification object:nil];
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
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self autorelease]; // balance self-retaining
}

- (void)dealloc
{
    [jobIds release];
    
    [super dealloc];
}

@end

@implementation GIActivityPanelController (TableViewDataSource)

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return [jobIds count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
    NSDictionary *progressInfo = [OPJobs progressInfoForJob:[jobIds objectAtIndex:rowIndex]];
    
    if (progressInfo)
    {
        NSString *identifier = [aTableColumn identifier];
        
        if ([identifier isEqualToString:@"progress"])
        {
            if ([progressInfo isJobProgressIndeterminate])
            {
                return @"Runs";
            }
            else
            {
                double minValue = [progressInfo jobProgressMinValue];
                double normalizedMax = [progressInfo jobProgressMaxValue] - minValue;
                double normalizedCurrentValue = [progressInfo jobProgressCurrentValue] - minValue;
                double percentComplete = (normalizedCurrentValue / normalizedMax) * (double)100.0;
                                
                return [NSString stringWithFormat:@"%d %%", (int) floor(percentComplete)];
            }
        }
        else if ([identifier isEqualToString:@"jobname"])
        {
            return [progressInfo jobProgressJobName]; 
        }
        else if ([identifier isEqualToString:@"description"])
        {
            return [progressInfo jobProgressDescription];
        }
    }

    return @""; // should not occur
}

@end
