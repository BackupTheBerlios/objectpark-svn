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
	
	[autosaveNames setObject:name forKey:self];
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
	
	if([[autosaveEnables objectForKey: self] boolValue]) // handle nil
	{
		flag = YES;
	}
	
	return flag;
}

- (void)_autosaveDidResize: (id)not
{
  float fact = 0.0;
  NSRect r1,r2;

  id subviews = [self subviews];

  if(![self autosaveName] || ![self autosaveDividerPosition])
    return;

  if([subviews count] != 2) {
    [NSException raise: @"NSInternalInconsistency" format: @"wrong number of subviews (%d)",
		 [subviews count]];
  }
  
  r1 = [[subviews objectAtIndex: 0] frame];
  r2 = [[subviews objectAtIndex: 1] frame];

  if([self isVertical]) 
    fact = r1.size.width / r2.size.width;
  else
    fact = r1.size.height / r2.size.height;

  {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *splitterConfig = [[defaults objectForKey: NSSplitViewPositionsKey] mutableCopy];
    NSNumber *thisConfig;

    if(splitterConfig == nil)
      splitterConfig = [NSMutableDictionary new];
    
    thisConfig = [NSNumber numberWithFloat: fact];
    [splitterConfig setObject: thisConfig forKey: [self autosaveName]];

    [defaults setObject: splitterConfig forKey: NSSplitViewPositionsKey];
    [defaults synchronize];
  }
}

- (void)_autosaveRestore
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSDictionary *splitterConfig = [defaults objectForKey: NSSplitViewPositionsKey];
  NSNumber *thisConfig;
  float ratio;
  NSView *v1,*v2;
  NSRect r1,r2;

  if(!splitterConfig) {
    return;
  }

  thisConfig = [splitterConfig objectForKey: [self autosaveName]];
  if(!thisConfig) {
    return;
  }

  ratio = [thisConfig floatValue];

  v1 = [[self subviews] objectAtIndex: 0];
  v2 = [[self subviews] objectAtIndex: 1];
  r1 = [v1 frame];
  r2 = [v2 frame];

  if([self isVertical]) {
    r1.size.width = ratio * r2.size.width;
    r2.size.width = r1.size.width / ratio;
  } else {
    r1.size.height = ratio * r2.size.height;
    r2.size.height = r1.size.height / ratio;
  }
  
  [v1 setFrame: r1];
  [v2 setFrame: r2];
}

@end
