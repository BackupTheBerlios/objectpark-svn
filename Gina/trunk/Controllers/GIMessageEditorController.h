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
@class OPSizingTokenField;

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
    IBOutlet OPSizingTokenField *toField;
    IBOutlet OPSizingTextField *subjectField;
    IBOutlet OPSizingTextField *hiddenTextFieldPrototype; /*" prototype for dynamic text fields "*/
    IBOutlet NSTextField *hiddenCaptionPrototype;
    IBOutlet NSPopUpButton *profileButton;
    IBOutlet GITextView *messageTextView;
    IBOutlet NSButton *profileValidationButton;
	
    NSWindowController *windowController;
    GIProfile *profile;
    GIMessage *referencedMessage;
	GIMessage *oldMessage;
    NSMutableDictionary *headerFields;	/*" Maps header names to header field content values "*/
    NSMutableAttributedString *content;
    BOOL shouldAppendSignature;
    int type;
    BOOL awoken;
	
    // -- Headers --
    NSMutableDictionary *headerTextFieldsForName;
    OPSizingTextField *bottomTextField;
    
    // -- Toolbar --
    NSArray *toolbarItems;
    NSArray *defaultIdentifiers;
	
	// -- OpenPGP --
    IBOutlet NSButton *signButton;
	IBOutlet NSButton *encryptButton;

	IBOutlet NSWindow *passphraseWindow;
	IBOutlet NSTextField *titleField;
	IBOutlet NSTextField *subtitleField;
	IBOutlet NSTextField *keyField;
	IBOutlet NSSecureTextField *passphraseField;
	IBOutlet NSButton *storeInKeychainCheckbox;
	IBOutlet NSTextField *errorMessage;
	
	id selectedKey;
	BOOL wasPassphraseDialogDismissed;
	
	NSArray *toFieldValue;
}

@property (retain) GIProfile* profile;
@property (retain) NSArray* toFieldValue;

- (id) initWithMessage: (GIMessage*) aMessage;
- (id) initNewMessageWithProfile: (GIProfile*) aProfile;
- (id) initReplyTo: (GIMessage*) aMessage all: (BOOL) toAll profile: (GIProfile*) aProfile;
- (id) initFollowupTo: (GIMessage*)  aMessage profile: (GIProfile*) aProfile;
- (id) initForward: (GIMessage*) aMessage profile: (GIProfile*) aProfile;
- (id) initNewMessageWithMailToDictionary: (NSDictionary*) aMailToDict;

- (GIMessage*) oldMessage;

- (BOOL)validateSelector: (SEL) aSelector;
- (GIProfile*) profile;

- (IBAction) addCc: (id) sender;
- (IBAction) addBcc: (id) sender;
- (IBAction) addReplyTo: (id) sender;
- (IBAction) replySender: (id) sender;
- (IBAction) replyAll: (id) sender;
- (IBAction) followup: (id) sender;
- (IBAction) saveDocument: (id) sender;
- (IBAction) send: (id) sender;
- (IBAction) queue: (id) sender;

@end

@interface GIMessageEditorController (Headers)

- (void)awakeHeaders;
- (void)updateHeaders;
- (BOOL)hasHeaderTextFieldWithFieldName: (NSString*) aFieldName;
- (OPSizingTextField*) headerTextFieldWithFieldName: (NSString*) aFieldName;
- (IBAction)switchProfile: (id) sender;
- (void)takeValuesFromHeaderFields;

@end

@interface GIMessageEditorController (ToolbarDelegate)

@end
