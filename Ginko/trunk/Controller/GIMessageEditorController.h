//
//  GIMessageEditorController.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 10.12.04.
//  Copyright 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "GIMessage.h"
#import "OPSizingTextField.h"
#import "GIProfile.h"

@class GITextView;

typedef enum 
{
    MessageTypeNewMessage,
    MassageTypeRevisitedMessage,
    MessageTypeReplyToSender,
    MessageTypeReplyToAll,
    MessageTypeFollowup,
    MessageTypeForward
} GIMessageType;

@interface GIMessageEditorController : NSObject 
{
    IBOutlet NSWindow *window;
    IBOutlet OPSizingTextField *toField;
    IBOutlet OPSizingTextField *subjectField;
    IBOutlet OPSizingTextField *hiddenTextFieldPrototype; /*" prototype for dynamic text fields "*/
    IBOutlet NSTextField *hiddenCaptionPrototype;
    IBOutlet NSPopUpButton *profileButton;
    IBOutlet GITextView *messageTextView;
    IBOutlet NSPopUpButton *toFieldOptionsButton;
    
    NSWindowController *windowController;
    GIProfile *profile;
    GIMessage *referencedMessage, *oldMessage;
    NSMutableDictionary *headerFields;	/*" Maps header names to header field content values "*/
    NSMutableAttributedString *content;
    BOOL shouldAppendSignature;
    int type;
    
    // -- Headers --
    NSMutableDictionary *headerTextFieldsForName;
    OPSizingTextField *bottomTextField;
    
    // -- Toolbar --
    NSArray *toolbarItems;
    NSArray *defaultIdentifiers;
}

- (id)initWithMessage: (GIMessage*) aMessage;
- (id)initNewMessageWithProfile: (GIProfile*) aProfile;
- (id)initReplyTo: (GIMessage*) aMessage all:(BOOL)toAll profile:(GIProfile *)aProfile;
- (id)initFollowupTo: (GIMessage*) aMessage profile:(GIProfile *)aProfile;
- (id)initForward: (GIMessage*) aMessage profile:(GIProfile *)aProfile;

- (BOOL)validateSelector:(SEL)aSelector;
- (GIProfile *)profile;

- (IBAction) addCc: (id) sender;
- (IBAction) addBcc: (id) sender;
- (IBAction) addReplyTo: (id) sender;
- (IBAction) replySender: (id) sender;
- (IBAction) replyAll: (id) sender;
- (IBAction) followup: (id) sender;
- (IBAction) saveMessage: (id) sender;

@end

@interface GIMessageEditorController (Headers)

- (void) awakeHeaders;
- (void) updateHeaders;
- (BOOL)hasHeaderTextFieldWithFieldName: (NSString*) aFieldName;
- (OPSizingTextField *)headerTextFieldWithFieldName: (NSString*) aFieldName;
- (IBAction)switchProfile:(id)sender;
- (void) takeValuesFromHeaderFields;

@end

@interface GIMessageEditorController (ToolbarDelegate)

- (void) awakeToolbar;
- (void) deallocToolbar;

@end