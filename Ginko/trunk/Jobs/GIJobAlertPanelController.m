/*
 $Id: GIJobAlertPanelController.m,v 1.4 2002/05/27 20:39:42 mikesch Exp $

 Copyright (c) 2002 by Axel Katerbau. All rights reserved.

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

#import "GIJobAlertPanelController.h"

NSString *GIJobAlertPanelWillCloseNotification = @"GIJobAlertPanelWillCloseNotification";

@implementation GIJobAlertPanelController
/*" Controller for job model dialogs. This dialogs have to run in the main (GUI)
    thread. This is why normal panels (e.g. NSRunAlertPanel) don't work.

    This class is the controller of the hand made panels for this occasion. "*/

- (id)initWithTitle:(NSString *)title message:(NSString *)message defaultButton:(NSString *)defaultButton alternateButton:(NSString *)alternateButton otherButton:(NSString *)otherButton duration:(NSTimeInterval)duration
/*" Opens a new job modal dialog panel with the given parameters which specify
    the title etc. "*/
{
    [super init];
    
    _title = [title retain];
    _message = [message retain];
    _defaultButton = [defaultButton retain];
    _alternateButton = [alternateButton retain];
    _otherButton = [otherButton retain];
    _duration = duration;
    
    if(! [NSBundle loadNibNamed:@"JobAlertPanel.nib" owner:self])
    {
        [self release];
        return nil;
    }
    return self;
}

- (void)dealloc
/*" Resources freed. "*/
{
    [_title release];
    [_message release];
    [_defaultButton release];
    [_alternateButton release];
    [_otherButton release];
    [_expiryTimer release];
    
    [super dealloc];
}

- (void)awakeFromNib
/*" Setup and display of the panel. "*/
{
    // balanced in -windowWillClose
    [self retain];

    // set up controls from paramters
    [panel setTitle:_title];
    [panelTitle setStringValue:_title];
    [panelMessage setStringValue:_message];

    if (_defaultButton)
        [panelDefaultButton setTitle:_defaultButton];

    if (_alternateButton)
        [panelAlternateButton setTitle:_alternateButton];
    else
        [panelAlternateButton removeFromSuperviewWithoutNeedingDisplay];

    if (_otherButton)
        [panelOtherButton setTitle:_otherButton];
    else
        [panelOtherButton removeFromSuperviewWithoutNeedingDisplay];

    // set up timer
    if (_duration > 0.0)
    {
        _expiryTimer = [[NSTimer scheduledTimerWithTimeInterval:_duration target:self selector:@selector(panelExpired:) userInfo:nil repeats:NO] retain];
    }
    
    // center panel
    [panel center];
    
    // show panel
    [panel makeKeyAndOrderFront:self];
}

- (void)windowWillClose:(NSNotification *)aNotification
/*" NSWindow delegate method. Balances the release count. "*/
{
    // stopping expiry timer
    [_expiryTimer invalidate];
    
    // balance retain count (retained in -awakeFromNib)
    [self autorelease];
}

- (void)panelExpired:(id)sender
/*" Action for the expiry timer.
    Closes the panel and signals the default button return code
    with a GIJobAlertPanelWillCloseNotification. "*/
{
    [self defaultButtonPressed:sender];
}

- (IBAction)defaultButtonPressed:(id)sender
/*" Action when the default button was pressed.
    Closes the panel and signals the default button return code
    with a GIJobAlertPanelWillCloseNotification. "*/
{
    [[NSNotificationCenter defaultCenter] postNotificationName:GIJobAlertPanelWillCloseNotification object:self userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:GIDefaultReturn]
        forKey:@"return"]];
    [panel close];
}

- (IBAction)alternateButtonPressed:(id)sender
    /*" Action when the default button was pressed.
    Closes the panel and signals the alternate button return code
    with a GIJobAlertPanelWillCloseNotification. "*/
{
    [[NSNotificationCenter defaultCenter] postNotificationName:GIJobAlertPanelWillCloseNotification object:self userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:GIAlternateReturn]
        forKey:@"return"]];
    [panel close];
}

- (IBAction)otherButtonPressed:(id)sender
    /*" Action when the default button was pressed.
    Closes the panel and signals the other button return code
    with a GIJobAlertPanelWillCloseNotification. "*/
{
    [[NSNotificationCenter defaultCenter] postNotificationName:GIJobAlertPanelWillCloseNotification object:self userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:GIOtherReturn]
        forKey:@"return"]];
    [panel close];
}

@end
