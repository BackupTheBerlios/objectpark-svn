//
//  GIMessageGroupOutlineViewController.m
//  Gina
//
//  Created by Axel Katerbau on 07.03.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "GIMessageGroupOutlineViewController.h"
#import "GIMessageGroup.h"
#import "GIMessageGroupCell.h"

@implementation GIMessageGroupOutlineViewController

- (void)awakeFromNib
{
//	[super awakeFromNib];
	
    // register for drag and drop
    //[outlineView registerForDraggedTypes:[NSArray arrayWithObjects:NSURLPboardType, nil]];
	
	[[outlineView tableColumnWithIdentifier:@"name"] setDataCell:[[[GIMessageGroupCell alloc] init] autorelease]];
	[[outlineView tableColumnWithIdentifier:@"unreadMessageCount"] setDataCell:[[[GIMessageGroupCell alloc] init] autorelease]];
	[outlineView sizeLastColumnToFit];
	
	[outlineView setColumnAutoresizingStyle:NSTableViewSequentialColumnAutoresizingStyle];
}


- (NSSet*) keyPathsAffectingDisplayOfItem: (id) item
{
	static NSSet* affectingKeyPaths = nil;
	if (! affectingKeyPaths) {
		affectingKeyPaths = [[NSSet setWithObjects: @"name", @"unreadMessageCount", nil] retain];
	}
	return affectingKeyPaths;
}

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{	
	if ([item isKindOfClass:[GIMessageGroup class]]) 
	{
		[cell setImage:[NSImage imageNamed:@"OtherMailbox"]];
	} 
	else 
	{
		[cell setImage:[NSImage imageNamed:@"Folder"]];
	}
	
	if ([cell isKindOfClass:[GIMessageGroupCell class]]) 
	{
		[cell setHierarchyItem:item];
	}
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	return YES;
}

@end


