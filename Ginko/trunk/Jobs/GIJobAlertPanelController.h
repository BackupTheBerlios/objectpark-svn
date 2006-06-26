/*
 $Id: GIJobAlertPanelController.h,v 1.2 2002/01/20 22:20:23 mikesch Exp $

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

#import <AppKit/AppKit.h>

#define GIDefaultReturn 0
#define GIAlternateReturn 1
#define GIOtherReturn 2

@interface GIJobAlertPanelController : NSObject
{
    IBOutlet NSPanel *panel;
    IBOutlet id panelTitle;
    IBOutlet id panelMessage;
    IBOutlet NSButton *panelDefaultButton;
    IBOutlet NSButton *panelAlternateButton;
    IBOutlet NSButton *panelOtherButton;

    @private NSString *_title;			/*" Title of the panel. "*/
    @private NSString *_message;		/*" Message of the panel. "*/
    @private NSString *_defaultButton;		/*" Text for the default button of the panel. "*/
    @private NSString *_alternateButton;	/*" Text for the alternate button of the panel. "*/
    @private NSString *_otherButton;		/*" Text for the other button of the panel. "*/
    @private NSTimeInterval _duration;		/*" Determines how long the panel will be shown. "*/
    @private NSTimer *_expiryTimer;		/*" Timer for expiration of the panel. "*/
}

/*" initialization "*/
- (id)initWithTitle:(NSString *)title message:(NSString *)message defaultButton:(NSString *)defaultButton alternateButton:(NSString *)alternateButton otherButton:(NSString *)otherButton duration:(NSTimeInterval)duration;

/*" actions "*/
- (IBAction)defaultButtonPressed:(id)sender;
- (IBAction)alternateButtonPressed:(id)sender;
- (IBAction)otherButtonPressed:(id)sender;

@end

extern NSString *GIJobAlertPanelWillCloseNotification;
/*" Notifies about the selection of a button. The userinfo dictinary holds
    a NSNumber with the respective constant (see constants) for the key 'return'. "*/


