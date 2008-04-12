//
//  GISplitView.h
//  Gina
//
//  Created by Axel Katerbau on 08.03.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface GISplitView : NSSplitView 
{
	CGFloat dividerThickness;
}

@property (readwrite) CGFloat dividerThickness;

@end
