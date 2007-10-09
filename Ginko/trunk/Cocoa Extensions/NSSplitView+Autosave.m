/* 
Copyright (c) 2006 by Objectpark Group. All rights reserved.
 
 Permission to use, copy, modify and distribute this software and its documentation
 is hereby granted, provided that both the copyright notice and this permission
 notice appear in all copies of the software, derivative works or modified versions,
 and any portions thereof, and that both notices appear in supporting documentation,
 and that credit is given to Axel Katerbau in all documents and publicity
 pertaining to direct or indirect use of this code or its derivatives.
 
 THIS IS EXPERIMENTAL SOFTWARE AND IT IS KNOWN TO HAVE BUGS, SOME OF WHICH MAY HAVE
 SERIOUS CONSEQUENCES. THE COPYRIGHT HOLDER ALLOWS FREE USE OF THIS SOFTWARE IN ITS
 "AS IS" CONDITION. THE COPYRIGHT HOLDER DISCLAIMS ANY LIABILITY OF ANY KIND FOR ANY
 DAMAGES WHATSOEVER RESULTING DIRECTLY OR INDIRECTLY FROM THE USE OF THIS SOFTWARE
 OR OF ANY DERIVATIVE WORK.
 
 Further information can be found on the project's web pages
 at http://www.objectpark.org/Ginko.html
 */

#import "NSSplitView+Autosave.h"

@interface NSSplitView (AutosavePrivate)
- (void)_autosaveRestore;
@end

@implementation NSSplitView (Autosave)

static NSMutableDictionary *autosaveNames = nil;
static NSMutableDictionary *autosaveEnables = nil;

static NSString *NSSplitViewPositionsKey = @"NSSplitViewPositions";

- (id)copyWithZone:(NSZone *)zone
{
	return [self retain];
}

- (void)setAutosaveName:(NSString *)name
{
	if (!autosaveNames)
	{
		autosaveNames = [NSMutableDictionary new];
	}
	if (name) {
		[autosaveNames setObject:name forKey:self];
	}
}

- (NSString *)autosaveName
{
	if (!autosaveNames)
	{
		autosaveNames = [NSMutableDictionary new];
	}
	
	return [autosaveNames objectForKey: self];
}

- (void)setAutosaveDividerPosition:(BOOL)flag
{
	BOOL oldflag = [self autosaveDividerPosition];
	
	if (!oldflag & flag ) 
	{
		[self _autosaveRestore];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(_autosaveDidResize:)
													 name:NSSplitViewDidResizeSubviewsNotification
												   object:self];
	}
	
	[autosaveEnables setObject:[NSNumber numberWithBool:flag]
						forKey:self];
}

- (BOOL)autosaveDividerPosition
{
	BOOL flag = NO;
	if (!autosaveEnables)
	{
		autosaveEnables = [NSMutableDictionary new];
	}
	
	if([[autosaveEnables objectForKey:self] boolValue]) // handle nil
	{
		flag = YES;
	}
	
	return flag;
}

- (void)_autosaveDidResize:(id)notification
{	
	if(![self autosaveName] || ![self autosaveDividerPosition])
		return;
	
	NSEnumerator *subviewsEnumerator = [[self subviews] objectEnumerator];
	NSView *subview;
	BOOL isVertical = [self isVertical];
	float overallSize = 0.0;
	
	// calculate overall width/height:
	while (subview = [subviewsEnumerator nextObject])
	{
		NSRect rect = [subview frame];
		
		if (isVertical)
		{
			overallSize += rect.size.width;
		}
		else
		{
			overallSize += rect.size.height;
		}
	}
	
	// calculate fractions:
	subviewsEnumerator = [[self subviews] objectEnumerator];
	NSMutableArray *fractions = [NSMutableArray arrayWithCapacity:[[self subviews] count]];
	
	while (subview = [subviewsEnumerator nextObject])
	{
		NSRect rect = [subview frame];
		
		if (isVertical)
		{
			[fractions addObject:[NSNumber numberWithFloat:rect.size.width/overallSize]];
		}
		else
		{
			[fractions addObject:[NSNumber numberWithFloat:rect.size.height/overallSize]];
		}
	}
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSMutableDictionary *splitterConfig = [[defaults objectForKey:NSSplitViewPositionsKey] mutableCopy];
	
	if(splitterConfig == nil)
	{
		splitterConfig = [NSMutableDictionary new];
	}
	
	[splitterConfig setObject:fractions forKey:[self autosaveName]];
	
	[defaults setObject:splitterConfig forKey:NSSplitViewPositionsKey];
	[defaults synchronize];
	
	[splitterConfig release];
}

- (void)_autosaveRestore
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSDictionary *splitterConfig = [defaults objectForKey:NSSplitViewPositionsKey];
	
	if (!splitterConfig) return;
	
	NSArray *fractions = [splitterConfig objectForKey:[self autosaveName]];
	if (!fractions) return;
	
	if (![fractions isKindOfClass:[NSArray class]])
	{
		NSLog(@"old splitview data...ignored");
		return;
	}
	
	if ([[self subviews] count] != [fractions count]) 
	{
		NSLog(@"number of subviews changed...ignored");
		return;
	}
	
	NSEnumerator *subviewsEnumerator = [[self subviews] objectEnumerator];
	NSView *subview;
	BOOL isVertical = [self isVertical];
	float overallSize = 0.0;
	
	// calculate overall width/height:
	while (subview = [subviewsEnumerator nextObject])
	{
		NSRect rect = [subview frame];
		
		if (isVertical)
		{
			overallSize += rect.size.width;
		}
		else
		{
			overallSize += rect.size.height;
		}
	}
	
	// set new sizes:
	// calculate fractions:
	int i;
	NSArray *views = [self subviews];
	
	for (i = 0; i < [views count]; i++)
	{
		subview = [views objectAtIndex:i];
		NSRect rect = [subview frame];
		
		if (isVertical)
		{
			rect.size.width = [[fractions objectAtIndex:i] floatValue] * overallSize;
		}
		else
		{
			rect.size.height = [[fractions objectAtIndex:i] floatValue] * overallSize;
		}
		
		[subview setFrame:rect];
	}
}

@end
