//
//  G3MessageEditorController.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 10.12.04.
//  Copyright 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "G3Message.h"
#import "OPSizingTextField.h"
#import "G3Profile.h"

@class GITextView;

typedef enum 
{
    MessageTypeNewMessage,
    MassageTypeRevisitedMessage,
    MessageTypeReplyToSender,
    MessageTypeReplyToAll,
    MessageTypeFollowup,
    MessageTypeForward
} G3MessageType;

@interface G3MessageEditorController : NSObject 
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
    G3Profile *profile;
    G3Message *referencedMessage, *oldMessage;
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

- (id)initWithMessage:(G3Message *)aMessage;
- (id)initNewMessageWithProfile:(G3Profile *)aProfile;
- (id)initReplyTo:(G3Message *)aMessage all:(BOOL)toAll profile:(G3Profile *)aProfile;
- (id)initFollowupTo:(G3Message *)aMessage profile:(G3Profile *)aProfile;
- (id)initForward:(G3Message *)aMessage profile:(G3Profile *)aProfile;

- (BOOL)validateSelector:(SEL)aSelector;
- (G3Profile *)profile;

- (IBAction)addCc:(id)sender;
- (IBAction)addBcc:(id)sender;
- (IBAction)addReplyTo:(id)sender;
- (IBAction)replySender:(id)sender;
- (IBAction)replyAll:(id)sender;
- (IBAction)followup:(id)sender;
- (IBAction)saveMessage:(id)sender;

@end

@interface G3MessageEditorController (Headers)

- (void)awakeHeaders;
- (void)updateHeaders;
- (BOOL)hasHeaderTextFieldWithFieldName:(NSString *)aFieldName;
- (OPSizingTextField *)headerTextFieldWithFieldName:(NSString *)aFieldName;
- (IBAction)switchProfile:(id)sender;
- (void)takeValuesFromHeaderFields;

@end

@interface G3MessageEditorController (ToolbarDelegate)

- (void)awakeToolbar;
- (void)deallocToolbar;

@end
