//
//  GIGroupInspectorController.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 07.03.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "GIGroupInspectorController.h"
#import "GIProfile.h"
#import "GIApplication.h"

#define STANDARDGROUP 0
#define DEFAULTGROUP 1
#define SENTGROUP 2
#define DRAFTGROUP 3
#define QUEUEDGROUP 4
#define SPAMGROUP 5
#define TRASHGROUP 6

@implementation GIGroupInspectorController

static GIGroupInspectorController *sharedInspector = nil;

- (int)groupTypeTagForGroup:(GIMessageGroup *)aGroup
{
	if ([GIMessageGroup defaultMessageGroup] == aGroup) return DEFAULTGROUP;
	if ([GIMessageGroup sentMessageGroup] == aGroup) return SENTGROUP;
	if ([GIMessageGroup draftMessageGroup] == aGroup) return DRAFTGROUP;
	if ([GIMessageGroup queuedMessageGroup] == aGroup) return QUEUEDGROUP;
	if ([GIMessageGroup spamMessageGroup] == aGroup) return SPAMGROUP;
	if ([GIMessageGroup trashMessageGroup] == aGroup) return TRASHGROUP;
	return STANDARDGROUP;
}

- (void)setupProfilePopUpButton
{
    NSEnumerator *enumerator;
    GIProfile *aProfile;
    
    [profileButton removeAllItems];
    
    // fill profiles in:
    enumerator = [[GIProfile allObjects] objectEnumerator];
    while ((aProfile = [enumerator nextObject])) {
        [profileButton addItemWithTitle: [aProfile valueForKey: @"name"]];
        [[profileButton lastItem] setRepresentedObject: aProfile];
    }
}

- (void)setGroup:(GIMessageGroup *)aGroup
{
    [group autorelease];
    group = [aGroup retain];
    
    [self setupProfilePopUpButton];
    [profileButton selectItemAtIndex:[profileButton indexOfItemWithRepresentedObject:[aGroup defaultProfile]]];
    
	// setup Type:
	[typeRadioButtons selectCellWithTag:[self groupTypeTagForGroup:aGroup]];
	
    [window makeKeyAndOrderFront:self];
}

+ (id)groupInspectorForGroup:(GIMessageGroup *)aGroup
{
    if (! sharedInspector)
    {
        sharedInspector = [[self alloc] init];
    }
    
    [sharedInspector setGroup:aGroup];
    
    return sharedInspector;
}

- (id)init
{
    if ((self = [super init]))
    {
        [NSBundle loadNibNamed:@"GroupInspector" owner:self];
    }
    
    return self;
}

- (void)awakeFromNib
{
}

- (IBAction)switchProfile:(id)sender
    /*" Triggered by the profile select popup. "*/
{
    GIProfile *newProfile;
    
    newProfile = [[profileButton selectedItem] representedObject];
    if ([group defaultProfile] != newProfile) // check if something to do
    {
        [group setDefaultProfile:newProfile];
        [NSApp saveAction:self];
    }
}

- (void)setGroupTypeTag:(int)aTag forGroup:(GIMessageGroup *)aGroup
{
	switch (aTag)
	{
		case DEFAULTGROUP:
			[GIMessageGroup setDefaultMessageGroup:aGroup];
			break;
		case SENTGROUP:
			[GIMessageGroup setSentMessageGroup:aGroup];
			break;
		case DRAFTGROUP:
			[GIMessageGroup setDraftMessageGroup:aGroup];
			break;
		case QUEUEDGROUP:
			[GIMessageGroup setQueuedMessageGroup:aGroup];
			break;
		case SPAMGROUP:
			[GIMessageGroup setSpamMessageGroup:aGroup];
			break;
		case TRASHGROUP:
			[GIMessageGroup setTrashMessageGroup:aGroup];
			break;
		default:
			break;
	}
}

- (IBAction)switchType:(id)sender
{
	int previousTypeTag = [self groupTypeTagForGroup:group];
	int newTypeTag = [[sender selectedCell] tag];
	
	if (previousTypeTag != newTypeTag)
	{
		if (previousTypeTag != STANDARDGROUP)
		{
			// set another standard group to the current special group:
			NSEnumerator *enumerator = [[GIMessageGroup allObjects] objectEnumerator];
			GIMessageGroup *otherGroup;
			BOOL foundOtherGroup = NO;
			
			while (otherGroup = [enumerator nextObject])
			{
				if ([self groupTypeTagForGroup:otherGroup] == STANDARDGROUP)
				{
					[self setGroupTypeTag:previousTypeTag forGroup:otherGroup];
					foundOtherGroup = YES;
					break;
				}
			}
			
			if (! foundOtherGroup)
			{
				NSBeep();
				return;
			}
		}
		
		[self setGroupTypeTag:newTypeTag forGroup:group];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:GIMessageGroupsChangedNotification object:[NSArray arrayWithObject:group]];
	}
}

@end
