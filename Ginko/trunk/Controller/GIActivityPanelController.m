//
//  GIActivityPanelController.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 05.06.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "GIActivityPanelController.h"
#import "OPJob.h"
#import "GIUserDefaultsKeys.h"

NSString *GIActivityPanelNeedsUpdateNotification = @"GIActivityPanelNeedsUpdateNotification";

@implementation GIActivityPanelController

static GIActivityPanelController *panel = nil;

+ (void)initialize
{
    static BOOL initialized = NO;
    
    if (! initialized)
    {
        [[NSNotificationCenter defaultCenter] addObserver:[self class] selector:@selector(activityStarted:) name:JobWillStartNotification object:nil]; 
        initialized = YES;
    }
}

+ (void)showActivityPanelInteractive:(BOOL)interactive
	/*" Set the interactive flag to indicate the the panel should be shown as a result of an interactive user request. "*/
{
    [[[self sharedInstance] window] orderFront:nil];
}

- (void)updateData
{
    [jobs autorelease];
    jobs = [[OPJob runningJobs] mutableCopy];
    
	// throw out hidden jobs:
	NSMutableArray *hiddenJobs = [NSMutableArray array];
	NSEnumerator *enumerator = [jobs objectEnumerator];
	OPJob *job;
	while (job = [enumerator nextObject])
	{
		if ([job isHidden]) [hiddenJobs addObject:job];
	}
	
	[jobs removeObjectsInArray:hiddenJobs];
	
    [tableView reloadData];
    
    if ([jobs count] == 0) // no jobs to show 
    {
        // close if automatic panel is active:
        if ([[NSUserDefaults standardUserDefaults] boolForKey:AutomaticActivityPanelEnabled])
        {
            [window close];
        }
    }
	else
	{
		if ([[NSUserDefaults standardUserDefaults] boolForKey:AutomaticActivityPanelEnabled])
		{
			[[self class] showActivityPanelInteractive:NO];
		}
	}
}

+ (void)updateData
{
    [panel updateData];
}

- (void)dataChanged:(NSNotification *)aNotification
{
    NSNotification *updateNotification = [NSNotification notificationWithName:GIActivityPanelNeedsUpdateNotification object:self];
    
    [[NSNotificationQueue defaultQueue] enqueueNotification:updateNotification postingStyle:NSPostWhenIdle coalesceMask:NSNotificationCoalescingOnName forModes:nil];
    
    /*
    [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateData) object:nil];
    [self performSelector:@selector(updateData) withObject:nil afterDelay:0.2];
     */
}

+ (id)sharedInstance 
{
	if (! panel) 
	{
        panel = [[self alloc] init];
    }
	
	return panel;
}

+ (void)activityStarted:(NSNotification *)aNotification
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:AutomaticActivityPanelEnabled])
    {        
		[[self sharedInstance] updateData];
				
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        
        [center addObserver:panel selector:@selector(updateData) name:GIActivityPanelNeedsUpdateNotification object:nil];        
        
        [center addObserver:panel selector:@selector(dataChanged:) name:JobDidFinishNotification object:nil];
        [center addObserver:panel selector:@selector(dataChanged:) name:JobDidSetProgressInfoNotification object:nil];
    }
}

- (id)init
{
    if (self = [super init]) 
    {
        [NSBundle loadNibNamed:@"Activity" owner:self];
        
        //[self retain]; // balanced in -windowWillClose:
        
        // register for notifications:
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        
        [center addObserver:self selector:@selector(updateData) name:GIActivityPanelNeedsUpdateNotification object:nil];        
        
        [center addObserver:self selector:@selector(dataChanged:) name:JobDidFinishNotification object:nil];
        [center addObserver:self selector:@selector(dataChanged:) name:JobDidSetProgressInfoNotification object:nil];        
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
	[window retain]; // goes away otherwise!
	//NSLog(@"ActivityViewer has %d columns.", [tableView numberOfColumns]);
}


- (IBAction)stopJob:(id)sender
{
	int rowIndex = [tableView clickedRow];

	[[jobs objectAtIndex:rowIndex] suggestTerminating];
	NSLog(@"Should stop thread: %@", [[jobs objectAtIndex:rowIndex] progressInfo]);
}

- (void)windowWillClose:(NSNotification *)notification 
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)dealloc
{
    [jobs release];
    [super dealloc];
	if (self==panel) panel = nil;
}

@end

@implementation GIActivityPanelController (TableViewDataSource)

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return [jobs count];
}

/*
- (BOOL) tableView: (NSTableView*) tableView shouldSelectRow: (int) row
{
	return NO;
}
*/

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	NSString *identifier = [aTableColumn identifier];
	//NSLog(@"Identifier: %@", identifier);
	/*
	 if ([identifier isEqualToString: @"progress"]) {
		 if ([progressInfo isJobProgressIndeterminate]) {
			 return @"Running";
		 } else {
			 double minValue = [progressInfo jobProgressMinValue];
			 double normalizedMax = [progressInfo jobProgressMaxValue] - minValue;
			 double normalizedCurrentValue = [progressInfo jobProgressCurrentValue] - minValue;
			 double percentComplete = (normalizedCurrentValue / normalizedMax) * (double)100.0;
			 
			 return [NSString stringWithFormat: @"%.1f %%\n%d/%d", percentComplete, (unsigned long)[progressInfo jobProgressCurrentValue], (unsigned long)[progressInfo jobProgressMaxValue]];
		 }
	 } else 
	 */
	if ([identifier isEqualToString:@"description"]) 
	{
		NSDictionary *progressInfo = [[jobs objectAtIndex:rowIndex] progressInfo];
		
		if (progressInfo) 
		{
			return [NSString stringWithFormat:@"%@ - %@", [[progressInfo jobProgressJob] name], [progressInfo jobProgressDescription]];
		}
    }
    
    return @""; // should not occur
}

- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	//NSLog(@"willDisplayCell %@", aCell);
	NSString *identifier = [aTableColumn identifier];

	if ([identifier isEqualToString:@"stopButton"]) {
		NSDictionary* progressInfo = [[jobs objectAtIndex:rowIndex] progressInfo];
		NSString* progressTitle = @"Running";
		if (! [progressInfo isJobProgressIndeterminate]) {
			double minValue = [progressInfo jobProgressMinValue];
			double normalizedMax = [progressInfo jobProgressMaxValue] - minValue;
			double normalizedCurrentValue = [progressInfo jobProgressCurrentValue] - minValue;
			double percentComplete = normalizedMax == 0.0 ? 0.0 : (normalizedCurrentValue / normalizedMax) * (double)100.0;
			
			//progressTitle = [NSString stringWithFormat: @"%.1f %%\n%d/%d", percentComplete, 
			progressTitle = [NSString stringWithFormat:@"%.1f %%", percentComplete]; 
			//	(unsigned long)[progressInfo jobProgressCurrentValue], 
			//	(unsigned long)[progressInfo jobProgressMaxValue]];
		}
		[aCell setTitle: progressTitle];
	}
}

@end
