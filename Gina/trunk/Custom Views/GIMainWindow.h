//
//  GIMainWindow.h
//  Gina
//
//  Created by Axel Katerbau on 11.01.08.
//  Copyright 2008 Objectpark Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface GIMainWindow : NSWindow 
{

}

@end

@protocol GIMainWindowDelegate

- (BOOL)keyPressed:(NSEvent *)event;

@end