//
//  OPPreferencePane.m
//  OPPreferencesTest
//
//  Created by Dirk Theisen on Sat Feb 02 2002.
//  Copyright (c) 2001 Dirk Theisen. All rights reserved.
//
/*
 Permission to use, copy, modify and distribute this software and its documentation
 is hereby granted, provided that both the copyright notice and this permission
 notice appear in all copies of the software, derivative works or modified versions,
 and any portions thereof, and that both notices appear in supporting documentation,
 and that credit is given to Bjoern Bubbat in all documents and publicity
 pertaining to direct or indirect use of this code or its derivatives.

 THIS IS EXPERIMENTAL SOFTWARE AND IT IS KNOWN TO HAVE BUGS, SOME OF WHICH MAY HAVE
 SERIOUS CONSEQUENCES. THE COPYRIGHT HOLDER ALLOWS FREE USE OF THIS SOFTWARE IN ITS
 "AS IS" CONDITION. THE COPYRIGHT HOLDER DISCLAIMS ANY LIABILITY OF ANY KIND FOR ANY
 DAMAGES WHATSOEVER RESULTING DIRECTLY OR INDIRECTLY FROM THE USE OF THIS SOFTWARE
 OR OF ANY DERIVATIVE WORK.

 Further information can be found on the project's web pages
 at http://www.objectpark.org/
 */

#import "OPPreferencePane.h"

@implementation OPPreferencePane

+ (id) pane
{
    return [[[self alloc] init] autorelease];
}

- (id) init
{
    return [self initWithBundle: nil];
}

- (NSBundle*) bundle
/*" This extension of -bundle falls back to +bundleForClass if no bundle was given to initWithBundle. "*/
{
    NSBundle* result = [super bundle];
    if (!result)
        result = [NSBundle bundleForClass: [self class]];
    return result;
}

- (NSView*) loadMainView
{
    if (![self mainView]) {
        if(![NSBundle loadNibNamed: [self mainNibName]
                             owner: self]) {
            NSLog(@"[%@ %@] Couldn't load nib %@ from Resources!",
                  [self class], NSStringFromSelector(_cmd), [self mainNibName]);
            return nil;
        }

        if ([self valueForKey: @"_window"]==nil)
            NSLog(@"OPPreferencePane: Warning - Window outlet in %@.nib not connected!", [self mainNibName]);
        [self assignMainView];
        [self mainViewDidLoad];
    }
    return [self mainView];
}


NSString* OPPreferencePaneDidEndEditing = @"OPPreferencePaneDidEndEditing";

- (void) didUnselect
{
	[[NSNotificationCenter defaultCenter] postNotificationName: OPPreferencePaneDidEndEditing object: self];
}



- (NSString*) mainNibName
{
    return NSStringFromClass([self class]);
}


- (NSString*) tooltip
{
    /*"Returns the string for the tooltip to be shown before the pane is activated. Defaults to nil."*/
    return nil;
}

@end

