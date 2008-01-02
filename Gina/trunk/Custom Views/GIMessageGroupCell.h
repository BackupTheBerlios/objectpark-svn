//
//  GIMessageGroupCell.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 13.10.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface GIMessageGroupCell : NSTextFieldCell 
{
	NSImage *image;
	id hierarchyItem;
}

- (id)hierarchyItem;
- (void)setHierarchyItem:(id)anItem;

@end
