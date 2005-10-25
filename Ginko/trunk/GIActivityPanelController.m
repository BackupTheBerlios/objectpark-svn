//
//  GIActivityPanelController.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 05.06.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "GIActivityPanelController.h"
#import "OPJobs.h"
#import "GIUserDefaultsKeys.h"

@implementation GIActivityPanelController

static GIActivityPanelController *panel = nil;

+ (void)initialize
{
    static BOOL initialized = NO;
    
    if (! initialized)
    {
        [[NSNotificationCenter defaultCenter] addObserver:[self class] selector:@selector(activityStarted:) name:OPJobWillStartNotification object:nil]; 
        initialized = YES;
    }
}

- (void)updateData
{
    [jobIds autorelease];
    jobIds = [[OPJobs runningJobs] retain];
    
    [tableView reloadData];
    
    if ([jobIds count] == 0) // no jobs to show 
    {
        // close if automatic panel is active:
        if ([[NSUserDefaults standardUserDefaults] boolForKey:AutomaticActivityPanelEnabled])
        {
            [window close];
        }
    }
}

+ (void)updateData
{
    [panel updateData];
}

- (void)dataChanged:(NSNotification *)aNotification
{
    [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateData) object:nil];
    [self performSelector:@selector(updateData) withObject:nil afterDelay:0.2];
}

+ (void)showActivityPanelInteractive:(BOOL)interactive
    /*" Set the interactive flag to indicate the the panel should be shown as a result of an interactive user request. "*/
{
    if (! panel) 
    {
        panel = [[self alloc] init];
    }
    
    [[panel window] orderFront:nil];
}

+ (void)activityStarted:(NSNotification *)aNotification
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:AutomaticActivityPanelEnabled])
    {
        [self showActivityPanelInteractive:NO];
        
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        
        [center addObserver:panel selector:@selector(dataChanged:) name:OPJobDidFinishNotification object:nil];
        [center addObserver:panel selector:@selector(dataChanged:) name:OPJobDidSetProgressInfoNotification object:nil];
    }
}

- (id)init
{
    if (self = [super init]) 
    {
        [NSBundle loadNibNamed: @"Activity" owner:self];
        
        //[self retain]; // balanced in -windowWillClose:
        
        // register for notifications:
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        
        [center addObserver:self selector:@selector(dataChanged:) name:OPJobDidFinishNotification object:nil];
        [center addObserver:self selector:@selector(dataChanged:) name:OPJobDidSetProgressInfoNotification object:nil];        
    }
    
    return self;
}

- (NSWindow *)window
{
    return window;
}

- (void)awakeFromNib
{
    [tableView reloadData];   
}

- (void)windowWillClose:(NSNotification *)notification 
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) dealloc
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
        else if ([identifier isEqualToString:@"absolute"])
        {
            if (![progressInfo isJobProgressIndeterminate])
            {
                return [NSString stringWithFormat:@"%lu/%lu", (unsigned long)[progressInfo jobProgressCurrentValue], (unsigned long)[progressInfo jobProgressMaxValue]];
            }
        }
    }
    
    return @""; // should not occur
}

@end
