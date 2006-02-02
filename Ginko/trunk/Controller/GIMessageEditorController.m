//
//  GIMessageEditorController.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 10.12.04.
//  Copyright 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "GIMessageEditorController.h"
#import "NSView+ViewMoving.h"
#import "NSAttributedString+Extensions.h"
#import "NSString+MessageUtils.h"
#import "NSArray+Extensions.h"
#import "GIApplication.h"
#import "GIProfile.h"
#import "GIAccount.h"
#import "NSToolbar+OPExtensions.h"
#import "GITextView.h"
#import "OPInternetMessage.h"
#import "OPInternetMessage+GinkoExtensions.h"
#import "GIMessage+Rendering.h"
#import "GIMessageBase.h"
#import "OPURLFieldCoder.h"
#import "EDTextFieldCoder.h"
#import "OPObjectPair.h"
#import "OPPersistentObject+Extensions.h"
#import <Foundation/NSDebug.h>
#import "GIAddressFormatter.h"
#import "GIPhraseBrowserController.h"

@interface GIMessageEditorController (PrivateAPI)
- (OPInternetMessage*) message;
- (GIMessage*) checkpointMessageWithStatus: (unsigned int) aType;
- (void) addReferenceToMessage: (GIMessage*) aMessage;
- (void) setHeadersFromMessage: (GIMessage*) aMessage;
- (void) appendContentFromMessage: (GIMessage*) aMessage;
- (void) appendForwardContentFromMessage: (GIMessage*) aMessage;
- (void) switchToReplyToAll: (GIMessage*) replyMessage;
- (void) switchToReplyToSender: (GIMessage*) replyMessage;
- (void) switchToFollowup: (GIMessage*) replyMessage;
- (void) appendQuotePasteboardContents;
- (void) setReplySubjectFromMessage: (GIMessage*) aMessage;
- (void) setReplyForwardSubjectFromMessage: (GIMessage*) aMessage;
- (void) updateMessageTextView;
- (void) updateWindowTitle;
- (BOOL) messageIsSendable;
@end

@implementation GIMessageEditorController

- (id) init
{
    if (self = [super init]) {
        // eager, isn't it?
        NSLog(@"GIMessageEditorController init");
        headerFields = [[NSMutableDictionary alloc] init];
        content = [[NSMutableAttributedString alloc] init];
        [self retain];
    }
    return self;
}

- (id)initWithMessage:(GIMessage *)aMessage
/*" For reopening an unsent message. "*/
{
    if (self = [self init]) 
    {        
		// Make sure, aMessage is not send during edit:
        if ([aMessage sendStatus]==OPSendStatusQueuedReady) [aMessage setSendStatus: OPSendStatusQueuedBlocked];
        
        profile = [[aMessage valueForKey: @"sendProfile"] retain];
        
        oldMessage = [aMessage retain];
        referencedMessage = nil;
        
        [self setHeadersFromMessage:oldMessage];
        [self appendContentFromMessage:oldMessage];
        
        shouldAppendSignature = NO;
        
        type = MassageTypeRevisitedMessage;
        
        [NSBundle loadNibNamed:@"MessageEditor" owner:self];
        
        [self updateHeaders];
        [self updateMessageTextView];
        [self updateWindowTitle];
        
        [window makeKeyAndOrderFront:self];
    }
    
    return self;
}

- (id) initNewMessageWithProfile: (GIProfile*) aProfile
{
    if (self = [self init]) {
        if (! aProfile) aProfile = [GIProfile defaultProfile];
        
        profile = [aProfile retain];
        referencedMessage = nil;
                
        shouldAppendSignature = YES;
                
        type = MessageTypeNewMessage;
        
        [NSBundle loadNibNamed: @"MessageEditor" owner: self];
        
        [self updateHeaders];
        [self updateMessageTextView];
        [self updateWindowTitle];
        
        [window makeKeyAndOrderFront: self];
    }
    
    return self;
}

- (id)initReplyTo: (GIMessage*) aMessage all:(BOOL)toAll profile:(GIProfile *)aProfile
{
    if (self = [self init]) {
        if (! aProfile) aProfile = [GIProfile defaultProfile];
        
        profile = [aProfile retain];
        referencedMessage = [aMessage retain];

        [self appendQuotePasteboardContents];
        [self addReferenceToMessage:aMessage];
        [self setReplySubjectFromMessage:aMessage];

        shouldAppendSignature = YES;
        
        if (toAll) {
            [self switchToReplyToAll:aMessage];
            type = MessageTypeReplyToAll;
        } else {
            [self switchToReplyToSender:aMessage];
            type = MessageTypeReplyToSender;
        }
        
        [NSBundle loadNibNamed:@"MessageEditor" owner:self];

        [self updateHeaders];
        [self updateMessageTextView];
        [self updateWindowTitle];
        
        [window makeFirstResponder:messageTextView];
        [window makeKeyAndOrderFront:self];
    }
        
    return self;
}

- (id)initFollowupTo: (GIMessage*) aMessage profile:(GIProfile *)aProfile
{
    if (self = [self init]) {
        if (! aProfile) aProfile = [GIProfile defaultProfile];
        
        profile = [aProfile retain];
        referencedMessage = [aMessage retain];
        
        [self appendQuotePasteboardContents];
        [self addReferenceToMessage:aMessage];
        [self setReplySubjectFromMessage:aMessage];
        
        type = MessageTypeFollowup;
        shouldAppendSignature = YES;
        
        [self switchToFollowup:aMessage];
        
        [NSBundle loadNibNamed:@"MessageEditor" owner:self];

        [self updateHeaders];
        [self updateMessageTextView];
        [self updateWindowTitle];
        
        [window makeFirstResponder: messageTextView];
        [window makeKeyAndOrderFront: self];
    }
        
    return self;
}

- (id) initForward: (GIMessage*) aMessage profile: (GIProfile*) aProfile
{
    if (self = [self init]) {
        if (! aProfile) aProfile = [GIProfile defaultProfile];
        profile = [aProfile retain];
        
        [self setReplyForwardSubjectFromMessage: aMessage];
		
		// We are adding a references header even to email forwardings in order to be able to
		// thread them correctly with the original mail forwarded - regardless of subject:
		
		if (![headerFields objectForKey: @"References"]) {
			[headerFields setObject: [aMessage messageId] forKey: @"References"];
		}
		
        [self appendForwardContentFromMessage: aMessage];
        type = MessageTypeForward;
        shouldAppendSignature = YES;
                
        [NSBundle loadNibNamed: @"MessageEditor" owner: self];
        
        [self updateHeaders];
        [self updateMessageTextView];
        [self updateWindowTitle];
        
        [window makeFirstResponder: messageTextView];
        [window makeKeyAndOrderFront: self];
    }
    return self;
}

static NSPoint lastTopLeftPoint = {0.0, 0.0};

- (void) awakeFromNib
{
    [self awakeHeaders];
    [self awakeToolbar];
        
    [[messageTextView layoutManager] setDefaultAttachmentScaling:NSScaleProportionally];
    
    // set up most recently used continuous spell check status:
    [messageTextView setContinuousSpellCheckingEnabled: [[NSUserDefaults standardUserDefaults] boolForKey:@"ContinuousSpellCheckingEnabled"]];
    
    lastTopLeftPoint = [window cascadeTopLeftFromPoint: lastTopLeftPoint];
    
    [GIPhraseBrowserController setTextView: messageTextView];
}

- (void)windowDidMove: (NSNotification*) aNotification
{
//    lastTopLeftPoint = NSMakePoint(0.0, 0.0);
}

- (void) windowDidBecomeKey: (NSNotification*) aNotification
{
    [GIPhraseBrowserController setTextView: messageTextView];
	[self validateSelectedProfile];
}

/*
- (void)windowDidResignKey:(NSNotification *)aNotification
{
    NSLog(@"Window did resign key.");
    [GIPhraseBrowserController invalidateTextView:messageTextView];
}
*/

- (void) dealloc
{
    NSLog(@"GIMessageEditorController dealloc");
    
    [headerTextFieldsForName release];
    [profile release];
    [referencedMessage release];
    [oldMessage release];
    [headerFields release];
    [content release];
    [windowController release];
    
    [self deallocToolbar];
    [window setDelegate:nil];

    [super dealloc];
}

// accessors
- (GIProfile*) profile
{
    return profile;
}

- (void) sendSheetDidEnd: (NSWindow*)sheet returnCode: (int) returnCode contextInfo: (void*) contextInfo
{
    if (returnCode == NSAlertDefaultReturn) {
        //GIMessage *message = [self checkpointMessageWithStatus:OPQueuedStatus];
        BOOL sendNow = [(NSNumber *)contextInfo boolValue];
        if (sendNow) {
#warning start message send job here
        }
        [window performClose:self];
    }
    
    [(NSNumber *)contextInfo release];
}

// actions
- (IBAction)send:(id)sender
{
	NSString* emailAddress = [[self profile] mailAddress];
	
    if (emailAddress && ([[toField stringValue] rangeOfString:emailAddress].location != NSNotFound)) {
        NSBeginAlertSheet(NSLocalizedString(@"Do you really want to send this message to yourself?", @"sendSoliloquySheet"),
                          NSLocalizedString(@"Send", @"sendSoliloquySheet"),
                          NSLocalizedString(@"Edit", @"sendSoliloquySheet"),
                          nil,    // other Button
                          window,
                          self,   // delegate
                          @selector(sendSheetDidEnd:returnCode:contextInfo:),
                          NULL,   // didDismissSelector,
                          [[NSNumber alloc] initWithBool: YES], // contextinfo
                          NSLocalizedString(@"The To: field contains one of your own email addresses. You can now send the message or edit it and remove the address.", @"sendSoliloquySheet")
                          );
        return;
    }
    
    //GIMessage *message = 
    [self checkpointMessageWithStatus: OPSendStatusQueuedReady];
#warning start message send job here

    [window performClose: self];
}

- (IBAction)queue:(id)sender
{
    if ([[toField stringValue] rangeOfString: [[self profile] mailAddress]].location != NSNotFound)
    {
        NSBeginAlertSheet(NSLocalizedString(@"Do you really want to send this message to yourself?", @"sendSoliloquySheet"),
                          NSLocalizedString(@"Send", @"sendSoliloquySheet"),
                          NSLocalizedString(@"Edit", @"sendSoliloquySheet"),
                          nil,    // other Button
                          window,
                          self,   // delegate
                          @selector(sendSheetDidEnd:returnCode:contextInfo:),
                          NULL,   // didDismissSelector,
                          [[NSNumber alloc] initWithBool: NO],   // contextinfo
                          NSLocalizedString(@"The To: field contains one of your own email addresses. You can now send the message or edit it and remove the address.", @"sendSoliloquySheet")
                          );
        return;
    }
    
    [self checkpointMessageWithStatus: OPSendStatusQueuedReady];
    [window performClose: self];
    [window close];
}

- (IBAction)saveMessage:(id)sender
{
    [self checkpointMessageWithStatus: OPSendStatusDraft];
}

- (IBAction)addCc:(id)sender
{
    [window makeFirstResponder: [self headerTextFieldWithFieldName: @"Cc"]];
}

- (IBAction)addBcc:(id)sender
{
    [window makeFirstResponder: [self headerTextFieldWithFieldName: @"Bcc"]];
}

- (IBAction)addReplyTo:(id)sender
{
    NSTextField *replyToField;
    
    replyToField = [self headerTextFieldWithFieldName: @"Reply-To"];

    [window makeFirstResponder: replyToField];
}

- (IBAction)replySender:(id)sender
{
    [self takeValuesFromHeaderFields];
    [self switchToReplyToSender:referencedMessage];
    [self updateHeaders];
}

- (IBAction)replyAll:(id)sender
{
    [self takeValuesFromHeaderFields];
    [self switchToReplyToAll:referencedMessage];
    [self updateHeaders];    
}

- (IBAction)followup:(id)sender
{
    [self takeValuesFromHeaderFields];
    [self switchToFollowup:referencedMessage];
    [self updateHeaders];    
}

- (BOOL)tabKeyPressed:(id)sender withmodifierFlags:(NSNumber*) modifierFlags
/*" Window delegate method. Handles tabKey. Returns YES, if key was handled, NO otherwise. "*/
{
    if ([[(NSView *)[window firstResponder] superview] superview] == bottomTextField)
    {
        if (! ([modifierFlags unsignedIntValue] & NSShiftKeyMask))
        {
            if (! [window makeFirstResponder:profileButton])
            {
                [window makeFirstResponder:messageTextView];
            }
            return YES;
        }
    }
    else if ([window firstResponder] == messageTextView)
    {
        if ([modifierFlags unsignedIntValue] & NSShiftKeyMask)
        {
            if (! [window makeFirstResponder:profileButton])
            {
                [window makeFirstResponder:bottomTextField];
            }
        }
        else
        {
            [window selectNextKeyView:sender];
        }
        
        return YES;
    }
    return NO;
}


// validation
- (BOOL)validateSelector:(SEL)aSelector
{
    if (aSelector == @selector(send:)) 
    {
        if([self messageIsSendable]) // && [self sendHostIsReachable])
        {
            return YES;
        }
        else
        {
            return NO;
        }
    }
    
    if (aSelector == @selector(queue:)) 
    {
        if([self messageIsSendable])
        {
            return YES;
        }
        else
        {
            return NO;
        }
    }
    
    if (aSelector == @selector(addCc:)) 
    {
        return ![self hasHeaderTextFieldWithFieldName: @"Cc"];
    }
    
    if (aSelector == @selector(addBcc:)) 
    {
        return ![self hasHeaderTextFieldWithFieldName: @"Bcc"];
    }
    
    if (aSelector == @selector(addReplyTo:)) 
    {
        return ![self hasHeaderTextFieldWithFieldName: @"Reply-To"];
    }
    
    if (aSelector == @selector(replySender:)) 
    {
        return (referencedMessage) && (type == MessageTypeReplyToAll) || (type == MessageTypeFollowup);
    }

    if (aSelector == @selector(replyAll:)) 
    {
        return (referencedMessage) && (type == MessageTypeReplyToSender) || (type == MessageTypeFollowup);
    }
    
    if (aSelector == @selector(followup:)) 
    {
        return (referencedMessage) && (((type == MessageTypeReplyToSender) || (type == MessageTypeReplyToAll))
                && ([referencedMessage isUsenetMessage] || ([referencedMessage isListMessage])));
    }
    
    /*
    if (aSelector == @selector(pasteAsQuotation:)) {
        return [[[NSPasteboard generalPasteboard] availableTypeFromArray: [NSArray arrayWithObjects:NSRTFDPboardType, NSRTFPboardType, NSStringPboardType, nil]] length] != 0;
    }
    */
    return YES;
}

- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem
{
    return [self validateSelector: [menuItem action]];
}

- (void)windowWillClose:(NSNotification *)notification 
{
    [GIPhraseBrowserController invalidateTextView:messageTextView];
    lastTopLeftPoint = NSMakePoint(0.0, 0.0);
    
    [self autorelease]; // balance self-retaining
}

- (void)dismissalSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
/*" Callback for sheet opened in -windowShouldClose: "*/
{    
    switch (returnCode)
    {
        case NSAlertDefaultReturn:
        {
            // save as draft
            [self checkpointMessageWithStatus:0];
            
            [window setDocumentEdited:NO];
            [window close];
            
            if (contextInfo == [NSApp delegate]) [NSApp terminate:self];
            break;
        }
        case NSAlertOtherReturn:
        {
            // dismiss
			// unmark message as blocked for sending
			if ([oldMessage sendStatus] == OPSendStatusQueuedBlocked) {
				[oldMessage setSendStatus: OPSendStatusQueuedReady]; 
			}
            
            [window setDocumentEdited:NO];
            [window close];
            
            if (contextInfo == [NSApp delegate]) [NSApp terminate:self];
            break;
        }
        default:
            break;
    }
}

- (BOOL)windowShouldClose:(id)sender
{
    if (! [window isDocumentEdited]) return YES;
    
    // ##WARNING axel->axel: might be a queued message also. Could be only a newer version...
    NSBeginAlertSheet(NSLocalizedString(@"Save Message as a Draft?", @"edit window close alert sheet"),
                      NSLocalizedString(@"Save", @"edit window close alert sheet"),
                      NSLocalizedString(@"Cancel", @"edit window close alert sheet"),
                      NSLocalizedString(@"Dismiss", @"edit window close alert sheet"),
                      window,
                      self,
                      @selector(dismissalSheetDidEnd:returnCode:contextInfo:),
                      NULL,
                      sender,
                      NSLocalizedString(@"Message can be sent later.", @"edit window close alert sheet")
                      );
    return NO;
}

- (void)textDidChange:(NSNotification *)aNotification
{
    [window setDocumentEdited:YES];
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
    id sender = [aNotification object];
    
    [window setDocumentEdited: YES];
    if ((sender == toField) || (sender == subjectField))
    {
        [self updateWindowTitle];
    }
}

@end

@implementation GIMessageEditorController (PrivateAPI)

// ### message generation ###

#define GINKOVERSION @"Ginko(Voyager)/%@ (See <http://www.objectpark.org>)"

- (NSString*) versionString
/*" Returns the version string for use in new messages' headers. "*/
{
    static NSString* versionString = nil;
    
    if (! versionString) {
        NSMutableString *bundleVersion = [[NSMutableString alloc] initWithString: [[[NSBundle mainBundle] infoDictionary] objectForKey: @"CFBundleVersion"]];
        // We replace spaces in the version number to make the version string compliant with RFC2616 and draft-ietf-usefor-article-09.txt (internet draft for news article format)
        [bundleVersion replaceOccurrencesOfString: @" " withString: @"-" options:NSLiteralSearch range:NSMakeRange(0, [bundleVersion length])];
        
        versionString = [[NSString alloc] initWithFormat:GINKOVERSION, bundleVersion];
        
        [bundleVersion release];
    }
    
    return versionString;
}

- (OPInternetMessage *)message
/*" Returns the current content of the message editor as a GIMessage. "*/
{
    OPInternetMessage *result = nil;
    NSEnumerator *enumerator;
    NSString *headerField, *from;
    GIProfile *theProfile = [self profile];

    // fills the headerFields dictionary from ui
    [self takeValuesFromHeaderFields];
    
    // create from header:
	if ([[theProfile valueForKey: @"realname"] length]) {
		from = [NSString stringWithFormat: @"%@ <%@>", [theProfile valueForKey: @"realname"], [theProfile mailAddress]];
	} else {
		from = [theProfile mailAddress];
	}
	[headerFields setObject: from forKey: @"From"];
    
    // organization:
	NSString* orga = [theProfile valueForKey: @"organization"];
    if ((! [result bodyForHeaderField: @"Organization"]) && ([orga length])) {
        [headerFields setObject: orga forKey: @"Organization"];
    }
    
    result = [OPInternetMessage messageWithAttributedStringContent: [messageTextView textStorage]];
    
    enumerator = [headerFields keyEnumerator];
    while(headerField = [enumerator nextObject])
    {
        EDHeaderFieldCoder *fieldCoder;
        NSString *fieldBody;
        
        // leaving out 'dangerous' header fields (the ones which are already set 
        // by messageWithAttributedStringContent:)
        if (! [result bodyForHeaderField:headerField])
        {
            fieldCoder = [[EDTextFieldCoder allocWithZone: [self zone]] initWithText: [[headerFields objectForKey:headerField] stringByRemovingLinebreaks]];
            
            fieldBody = [fieldCoder fieldBody];
            
            [fieldCoder release];
            
            // sanity check
            if ( ([headerField caseInsensitiveCompare: @"Cc"] == NSOrderedSame)
                 || ([headerField caseInsensitiveCompare: @"Bcc"] == NSOrderedSame) )
            {
                if (! [[fieldBody stringByRemovingSurroundingWhitespace] length])
                    continue;
            }
            
            [result setBody:fieldBody forHeaderField:headerField];
        }
    }
    
    // date
    //    [message setBody: [[NSCalendarDate calendarDate] descriptionWithCalendarFormat: @"%a, %d %b %Y %H:%M:%S %z (%Z)"] forHeaderField:@"Date"];
    [result setDate: [NSCalendarDate calendarDate]];
    
    // message id
    [result generateMessageIdWithSuffix: [NSString stringWithFormat: @"@%@", [[theProfile valueForKey: @"sendAccount"] outgoingServerName]]];
    
    // mailer info
/*     if([result isUsenetMessage])
     {
         [result setBody: [self versionString] forHeaderField: @"User-Agent"];
     }
     else
     {*/
	[result setBody: [self versionString] forHeaderField: @"X-Mailer"];
/*     }*/
    
    return result;
}

- (void) addReferenceToMessage: (GIMessage*) aMessage
/*"Adds a "references:" or "In-Reply-To:" header to the message to create."*/
{
    if ([aMessage isUsenetMessage]) {
		
        NSMutableString* references = [[[aMessage internetMessage] bodyForHeaderField: @"references"] mutableCopy];
        
		// Build References: header line:
        if (! references) {
            references = [[NSMutableString alloc] init];
        }
        
        if ([references length] == 0) {
            NSString* inReplyTo = [[aMessage internetMessage] bodyForHeaderField: @"In-Reply-To"];
            
            if (inReplyTo) {
                [references setString: inReplyTo];
            }
        }
        
        // A header line is not allowed to have a length of more than 998 characters plus terminating CRLF,
        // so we have to ensure the header line doesn't exceed 998 characters
        if ([references length] + [[[aMessage internetMessage] messageId] length] > 998-13)  // max headerline length - "References: " - " "
        {
            // This implementation is compliant to RFC 1036, but doesn't comply to the grammar defined in USEFOR's
            // draft which allows CFWS insteac of a space between the mids
            int skipped = 0;
            int charactersToRemove = [references length] + [[[aMessage internetMessage] messageId] length] + 13 - 998;
            NSString* referenceToSkip;
			NSString* reference;
            NSArray* referencesArray = [references componentsSeparatedByString: @" "];
            
            if ([referencesArray count]) {
                NSEnumerator *referencesList = [referencesArray objectEnumerator];
                
                [references setString: [referencesList nextObject]];
                
                while ((skipped < charactersToRemove) && (referenceToSkip = [referencesList nextObject])) {
                    skipped += [referenceToSkip length] + 1;
                }
                while (reference = [referencesList nextObject]) {
                    [references appendString: @" "];
                    [references appendString: reference];
                }
            }
        }
        
        if ([references length])
        {
            [references appendString: @" "];
        }
        
        if ([[[aMessage internetMessage] messageId] length])
        {
            [references appendString: [[aMessage internetMessage] messageId]];
        }
        
        if ([references length])
        {
            [headerFields setObject: references forKey: @"References"];
        }
        
        [references release];
    }
    
    if ([aMessage isEMailMessage])  // Make In-Reply-To: header line
    {
        [headerFields setObject: [[aMessage internetMessage] messageId] forKey: @"In-Reply-To"];
    }
}

- (void) appendQuotePasteboardContents
/*"Appends the content of the QuotePasteboard to the message text."*/
{
    NSPasteboard *quotePasteboard;
    
    quotePasteboard = [NSPasteboard pasteboardWithName: @"QuotePasteboard"];
    
    if (quotePasteboard)
    {
        NSString *quote;
        
        if (quote = [GITextView plainTextQuoteFromPasteboard:quotePasteboard])
        {
            [content appendString:quote];
        }
    }
}

- (void) appendContentFromMessage: (GIMessage*) aMessage
{
    [content appendAttributedString: [[aMessage internetMessage] editableBodyContent]];
}

- (void) setReplySubjectFromMessage: (GIMessage*) aMessage
{
    NSString *replySubject;
    OPInternetMessage *internetMessage = [aMessage internetMessage];
    
    @try {
        replySubject = [internetMessage replySubject];
		
    } @catch (NSException* localException) {
		
        if (NSDebugEnabled) NSLog(@"Fallback to raw subject header.");
        replySubject = [internetMessage bodyForHeaderField: @"Subject"];
    }
    
    [headerFields setObject: replySubject ? replySubject : @"Re: " forKey: @"Subject"];	
}

- (void) setReplyForwardSubjectFromMessage: (GIMessage*) aMessage
{
    OPInternetMessage* internetMessage = [aMessage internetMessage];
    
    @try {
        [headerFields setObject: [internetMessage forwardSubject] forKey: @"Subject"];
		
    } @catch (NSException* localException) {
		
        if (NSDebugEnabled) NSLog(@"Fallback to raw subject header.");
        [headerFields setObject: [@"FWD: " stringByAppendingString: [internetMessage bodyForHeaderField: @"Subject"]] forKey: @"Subject"];
    }
}

- (void)setHeadersFromMessage:(GIMessage *)aMessage
{
    NSEnumerator *enumerator = [[[aMessage internetMessage] headerFields] objectEnumerator];
	OPObjectPair *headerField;

    while ((headerField = [enumerator nextObject])) 
    {
        EDHeaderFieldCoder *coder = [EDHeaderBearingObject decoderForHeaderField:headerField];        
        [headerFields setObject:[coder stringValue] forKey:[headerField firstObject]];
    }
    
    NSLog(@"headers = %@", headerFields);
}

- (NSMutableString *)stringByRemovingOwnAddressesFromString:(NSString *)addr
{
    NSArray *parts = [addr fieldListFromEMailString];
    NSMutableString *result = [NSMutableString string];
    NSEnumerator *enumerator;
    NSString *part;
    
    enumerator = [parts objectEnumerator];
    while (part = [enumerator nextObject])
    {
        part = [part stringByRemovingSurroundingWhitespace];
        
        if ([part length]) 
        {
            if (! [GIProfile isMyEmailAddress:part]) 
            {
                if ([result length]) [result appendString:@", "]; // skip first time
                [result appendString:part];
            }
        }
    }
    if (NSDebugEnabled) NSLog(@"%@ stringByRemovingOwnAddressesFromString => %@", addr, result);
    
    return result;
}

- (void) switchToReplyToAll: (GIMessage*) replyMessage
{
    // Build the new to: header line. This includes the original to: content
    // sans myself plus the sender's ReplyTo:
    NSString *oldTo;
    NSMutableString* toAllButMe;
    
    oldTo = [NSString stringWithFormat: @"%@, %@", [[replyMessage internetMessage] replyToWithFallback: YES], makeStringIfNil([[replyMessage internetMessage] toWithFallback: YES])];
    
    // Try to remove myself from list (if included):
    toAllButMe = [self stringByRemovingOwnAddressesFromString:oldTo];
    
    // Write the new to: header:
    [headerFields setObject: toAllButMe forKey: @"To"];
    
    // Build the new cc: header line. This includes the original cc: content
    // sans myself:
    NSString *oldCC = [[replyMessage internetMessage] ccWithFallback: YES];
    
    // Try to remove myself from list (if included):
    NSMutableString* ccAllButMe = [self stringByRemovingOwnAddressesFromString: oldCC];
    
    if ([ccAllButMe length]) {
        [headerFields setObject: ccAllButMe forKey: @"Cc"];
    } else {
        [headerFields setObject: @"" forKey:@"Cc"];
    }
    
    type = MessageTypeReplyToAll;
}

- (void) switchToReplyToSender: (GIMessage*) replyMessage
{
    // If we are replying to our own message, we probably want is to send a message to the recients (to header)
    NSString* preSetTo = [[replyMessage internetMessage] replyToWithFallback: YES];
    
    if ([replyMessage hasFlags: OPIsFromMeStatus])  {
        NSString* preSetCc = [[replyMessage internetMessage] ccWithFallback: YES];
        
        if ([preSetCc length]) {
            [headerFields setObject: preSetCc forKey: @"Cc"];
        } else {
            [headerFields setObject: @"" forKey: @"Cc"];
        }
        
        preSetCc = [[replyMessage internetMessage] bccWithFallback: YES];
        
        if ([preSetCc length]) {
            [headerFields setObject: preSetCc forKey: @"Bcc"];
        } else {
            [headerFields setObject: @"" forKey: @"Bcc"];
        }
        
        preSetTo = [[replyMessage internetMessage] toWithFallback: YES];
    } else {
        NSString* Cc = [[self profile] valueForKey: @"defaultCc"];
        if (![Cc length]) Cc = @"";
        NSString* Bcc = [[self profile] valueForKey: @"defaultBcc"];
        if (![Bcc length]) Bcc = @"";
        
        [headerFields setObject: Cc forKey: @"Cc"];
        [headerFields setObject: Bcc forKey: @"Bcc"];
    }
    
    [headerFields setObject: makeStringIfNil(preSetTo) forKey: @"To"];
    
    type = MessageTypeReplyToSender;
}

- (void) switchToFollowup: (GIMessage*) replyMessage
{
    type = MessageTypeFollowup;

    // Make usenet replies take precedence to list replies:
    if ([replyMessage isUsenetMessage]) {
        // Set the Newsgroups: header to To. Primitive!! More checks needed!
        [headerFields setObject: [[replyMessage internetMessage] bodyForHeaderField: @"Newsgroups"] forKey: @"To"];
        return;
    }
    
    if ([replyMessage isEMailMessage]) {
        // try to identify a mailing list:
        NSString* rawPostString = [[replyMessage internetMessage] bodyForHeaderField: @"List-Post"];
        
        if ([rawPostString length]) {
            NSString *postURLString = [OPURLFieldCoder stringFromFieldBody:rawPostString withFallback: YES];
            
            if (postURLString) {
                [headerFields setObject: postURLString forKey: @"To"];
                return;
            }
        }
        NSLog(@"Unable to determine way to post to group (%@)", rawPostString);
    }
    
    NSBeep();
    NSLog(@"Unable to determine way to post to group.");
    return;
}

- (void) appendForwardContentFromMessage: (GIMessage*) aMessage
{
    OPInternetMessage*internetMessage = [aMessage internetMessage];
    
    NSAttributedString* forwardPrefix = [[[NSAttributedString allocWithZone: [self zone]] initWithString: @"\n\n==== BEGIN FORWARDED MESSAGE ====\n"] autorelease];
    
    NSAttributedString* forwardSuffix = [[[NSAttributedString allocWithZone: [self zone]] initWithString: @"\n==== END FORWARDED MESSAGE ====\n\n"] autorelease];
    
    NSAttributedString* forwardHeaders = [GIMessage renderedHeaders: [NSArray arrayWithObjects: @"From", @"Subject", @"To", @"Cc", @"Bcc", @"Reply-To", @"Date", nil] forMessage: internetMessage showOthers: NO];
    
    NSMutableAttributedString* result = [[[NSMutableAttributedString alloc] init] autorelease];
    
    [result appendAttributedString: forwardPrefix];
    [result appendAttributedString: forwardSuffix];
    [result insertAttributedString: [internetMessage editableBodyContent] atIndex: [forwardPrefix length]];
    [result insertAttributedString: forwardHeaders atIndex: [forwardPrefix length]];
    
    [content appendAttributedString: result];
}

- (NSAttributedString*) signature 
/*"Returns the signature of the current profile."*/
{	
	@try {
		NSAttributedString* signature = [[self profile] valueForKey: @"signature"];
		
		if ([signature length]) {
			NSMutableAttributedString* result = [[[NSMutableAttributedString alloc] initWithString: @"\n-- \n"] autorelease];
			[result appendAttributedString: signature];
			
			return result;
		}
	} @catch (NSException* exception) {
		NSLog(@"Warning: Unable to append signature: %@", exception);
	}
    
    return nil;
}

- (void) updateSignature
{
    NSMutableAttributedString* messageText = [messageTextView textStorage];
    NSRange signatureRange = [[messageText string] rangeOfString: @"\n-- \n" options:NSBackwardsSearch | NSLiteralSearch];
    
    if (signatureRange.location != NSNotFound) {
        signatureRange.length = [messageText length] - signatureRange.location;
        [messageText deleteCharactersInRange: signatureRange];
    }
    
    NSAttributedString* signature = [self signature];
    
    if ([signature length]) {
        NSRange selectedRange = [messageTextView selectedRange];
        [messageText appendAttributedString:signature];
        
        if ((selectedRange.location + selectedRange.length) < [messageText length]) {
            [messageTextView setSelectedRange: selectedRange];
        }
    }    
}

- (void) updateMessageTextView
/*" Sets the message text view contents to content plus X. ;-) "*/
{
    NSRange selectedRange;
    
    // set content in text view
    [[messageTextView textStorage] replaceCharactersInRange:NSMakeRange(0, [[messageTextView textStorage] length]) withAttributedString:content];
        
    // place insertion marker behind content
    selectedRange = NSMakeRange([[messageTextView textStorage] length], 0);
    
    if (shouldAppendSignature)
    {
        [self updateSignature];
        
        /*
        NSAttributedString *signature = [self signature];
        
        if ([signature length])
        {
            [[messageTextView textStorage] appendAttributedString:signature];
        }
         */
    }
    
    [messageTextView setSelectedRange:selectedRange];
    
    // override font of the whole body text
    [[messageTextView textStorage] addAttribute:NSFontAttributeName value: [GIMessage font] range:NSMakeRange(0, [[messageTextView textStorage] length])];
    
    // set typing font
    [messageTextView setTypingAttributes: [NSDictionary dictionaryWithObject: [GIMessage font] forKey:NSFontAttributeName]];    
}

- (void) updateWindowTitle
{
    NSString *subject = [[self headerTextFieldWithFieldName: @"Subject"] stringValue];
    NSString *to = [[self headerTextFieldWithFieldName: @"To"] stringValue];
    NSString *typeString = nil;
    
    switch (type)
    {
        case MessageTypeNewMessage:
            typeString = NSLocalizedString(@"New Message", @"Message Type String");
            break;
        case MassageTypeRevisitedMessage:
            typeString = NSLocalizedString(@"Draft", @"Message Type String");
            break;
        case MessageTypeReplyToSender:
        case MessageTypeReplyToAll:
            typeString = NSLocalizedString(@"Reply", @"Message Type String");
            break;
        case MessageTypeFollowup:
            typeString = NSLocalizedString(@"Followup", @"Message Type String");
            break;
        case MessageTypeForward:
            typeString = NSLocalizedString(@"Forward", @"Message Type String");
            break;
        default:
            break;
    }
    
    if ([to length]) 
    {
        NSString *format = [subject length] ?
        NSLocalizedString(@"%@ to %@ regarding '%@'", @"Message Window Title when subject is present") :
        NSLocalizedString(@"%@ to %@", @"Message Window Title when subject is not present");
        
        [window setTitle: [NSString stringWithFormat:format, typeString, [to realnameFromEMailStringWithFallback], [subject stringByRemovingReplyPrefix]]];
    } 
    else 
    {
        [window setTitle:typeString];
    }
}

- (GIMessage*) checkpointMessageWithStatus: (unsigned) sendStatus
{
    GIMessage* message = nil;
    
    message = [GIMessage messageWithTransferData: [[self message] transferData]];
    NSAssert1(message != nil, @"-[GIMessageEditorController checkpointMessageWithStatus]: Message should be created with transferData: %@", [[self message] transferData]);
    
    // status
    if (oldMessage) [message addFlags: [oldMessage flags]];
    [message addFlags: OPSeenStatus | OPIsFromMeStatus];
    
    // unmark message as blocked for sending
    [message setSendStatus: sendStatus];
	
    // Remove old message from database if present:
	[oldMessage delete];
    
    if (sendStatus == OPSendStatusDraft) {
        //add new message to database
        [GIMessageBase addDraftMessage: message];
    } else {
        [GIMessageBase addQueuedMessage: message];
    }
    
    [oldMessage autorelease];
    oldMessage = [message retain];
    
    // Set answered status if reply:
    [referencedMessage addFlags: OPAnsweredStatus]; // dth: shouldn't we do that on send?
    
    // Set message in profile's messagesToSend:
    [profile addValue: message forKey: @"messagesToSend"];
    
    [window setDocumentEdited: NO];
    
    [NSApp saveAction: self];

    //if (NSDebugEnabled) NSLog(@"checkpointed message");
    
    return message;
}

#define FORBIDDENCHARS @" []\\"

- (BOOL) messageIsSendable
	/*" A message is sendable if "to" and "subject" is filled out (nonempty). "*/
{
    NSString* to = [toField stringValue];
    NSString* subject = [subjectField stringValue];
    
    if (([to length]) && ([subject length])) {
				
        static NSCharacterSet* forbiddenCharacters = nil;
        if (! forbiddenCharacters)
            forbiddenCharacters = [[NSCharacterSet characterSetWithCharactersInString:FORBIDDENCHARS] retain];
        
        @try {
            NSArray* recipients = [to addressListFromEMailString];
            
            if ([recipients count]) {
                NSEnumerator *enumerator;
                NSString *recipient;
                
                enumerator = [recipients objectEnumerator];
                while (recipient = [enumerator nextObject])
                {
                    // must contain no chars from "forbidden" set
                    if ([recipient rangeOfCharacterFromSet: forbiddenCharacters 
												   options: 0 
													 range: NSMakeRange(0, [recipient length])].location != NSNotFound) {
                        return NO;
                    }
                    
                    if (! [recipient canBeConvertedToEncoding: NSASCIIStringEncoding]) {
                        return NO;
                    }
                }
				return YES;
            }
        } @catch (NSException* localException) {
			// Returns NO
		}
    }
    return NO;
}

@end

@implementation GIMessageEditorController (Headers)
/*" All things message header. "*/

NSArray* headerOrder()
/*" Returns an array which denotes the order in which the header fields should be displayed. Where the first header field name is to displayed topmost and the last bottommost. If the field name is not in this list it is to be append at the bottom without a preference for ordering. "*/
{
    static NSArray* order = nil;
    
    if (! order) {
        order = [[NSArray alloc] initWithObjects: @"Newsgroups", @"To", @"Subject", @"Cc", @"Bcc", @"Reply-To", nil];
    }
    
    return order;
}

#define DEFAULTMAXLINES (4)

NSDictionary *maxLinesForCalendarName()
/*" Returns a dictionary that gives the max. lines to display in the header field for a given header field name. If the dictionary returns no result, assume the default max. lines. "*/
{
    static NSDictionary *dict = nil;
    
    if (! dict)
    {
        NSMutableDictionary *d;
        
        d = [NSMutableDictionary dictionary];
        [d setObject: [NSNumber numberWithInt:2] forKey: @"Subject"];
        [d setObject: [NSNumber numberWithInt:1] forKey: @"Reply-To"];
        
        dict = [d copy];
    }
    
    return dict;
}

- (void) setupProfilePopUpButton
{
    NSEnumerator* enumerator;
    GIProfile* aProfile;
    
    [profileButton removeAllItems];
    
    // fill profiles in:
    enumerator = [[GIProfile allObjects] objectEnumerator];
    while (aProfile = [enumerator nextObject]) {
        [profileButton addItemWithTitle: [aProfile valueForKey: @"name"]];
        [[profileButton lastItem] setRepresentedObject:aProfile];
    }
}

- (void) validateSelectedProfile
{
	// Validate button with exclamation mark to indicate that the selected profile is not set up correctly.
	NSArray* validationErrors = [profile validationErrors];	
	[profileValidationButton setHidden: validationErrors == nil];
	if (validationErrors) [profileValidationButton setToolTip: [[validationErrors arrayByMappingWithSelector: @selector(localizedDescription)] componentsJoinedByString: @"\n"]];	
}

- (void) selectProfile: (GIProfile*) aProfile
{
    NSString* text;
	NSString* oldText;
    NSTextField* field;
    
    GIProfile* oldProfile = profile;
    [profile autorelease];
    profile = [aProfile retain];
    
	
    if (profile) {
        // select active profile:
        [profileButton selectItemAtIndex: [profileButton indexOfItemWithRepresentedObject:profile]];
    }
	
	[self validateSelectedProfile];
    
    // Cc:
    if ([self hasHeaderTextFieldWithFieldName: @"Cc"]) {
        field = [self headerTextFieldWithFieldName: @"Cc"];
        
        oldText = [oldProfile valueForKey: @"defaultCc"];
        oldText = oldText ? oldText : @"";
        
        if ([[field stringValue] isEqualToString:oldText]) {
            [field setStringValue: @""];
        }
    }
        
    if ((text = [profile valueForKey: @"defaultCc"]))
    {
        field = [self headerTextFieldWithFieldName: @"Cc"];
        if (! [[field stringValue] length])
        {
            [field setStringValue:text];
        }
    }
    
    // Bcc:
    if ([self hasHeaderTextFieldWithFieldName: @"Bcc"]) {
        field = [self headerTextFieldWithFieldName: @"Bcc"];
        
        oldText = [oldProfile valueForKey: @"defaultBcc"];
        oldText = oldText ? oldText : @"";
        
        if ([[field stringValue] isEqualToString:oldText]) {
            [field setStringValue: @""];
        }
    }

    if ((text = [profile valueForKey: @"defaultBcc"])) {
        NSTextField *field = [self headerTextFieldWithFieldName: @"Bcc"];
        if (! [[field stringValue] length]) {
            [field setStringValue:text];
        }
    }
    
    // Reply-To:
    if ([self hasHeaderTextFieldWithFieldName: @"Reply-To"]) {
        field = [self headerTextFieldWithFieldName: @"Reply-To"];
        
        oldText = [oldProfile valueForKey: @"defaultReplyTo"];
        oldText = oldText ? oldText : @"";
        
        if ([[field stringValue] isEqualToString: oldText]) {
            [field setStringValue: @""];
        }
    }
    
    if ((text = [profile valueForKey: @"defaultReplyTo"])) {
        NSTextField *field = [self headerTextFieldWithFieldName: @"Reply-To"];
        if (! [[field stringValue] length]) {
            [field setStringValue:text];
        }
    }
}

- (IBAction)switchProfile:(id)sender
/*" Triggered by the profile select popup. "*/
{
    GIProfile* newProfile = [[profileButton selectedItem] representedObject];
	// Check if something to do:
    if ([self profile] != newProfile)  {
        [self selectProfile: newProfile];
        [self updateSignature];
        [window setDocumentEdited: YES];
    }
}

- (void) awakeHeaders
/*" The awakeFromNib part of the Headers category. "*/
{
    unsigned maxLines;
    
    // prepare dictionary for looking up header fields:
    headerTextFieldsForName = [[NSMutableDictionary alloc] init];
    [headerTextFieldsForName setObject: toField forKey: @"To"];
    [headerTextFieldsForName setObject: subjectField forKey: @"Subject"];
    bottomTextField = subjectField;
    
    maxLines = [[maxLinesForCalendarName() objectForKey: @"To"] unsignedIntValue];
    maxLines = maxLines ? maxLines : DEFAULTMAXLINES;
    [toField setMaxLines:maxLines];
    
    //NSLog(@"toField _fancyTokenizingCharacterSet = %d", [[[toField cell] valueForKey: @"_fancyTokenizingCharacterSet"] characterIsMember:' ']);

    //[[[toField cell] valueForKey: @"_fancyTokenizingCharacterSet"] removeCharactersInString: @" ."];
    //NSLog(@"toField _fancyTokenizingCharacterSet = %d", [[[toField cell] valueForKey: @"_fancyTokenizingCharacterSet"] characterIsMember:' ']);

    //NSLog(@"toField charset = %d", [[toField tokenizingCharacterSet] characterIsMember:' ']);
    
    maxLines = [[maxLinesForCalendarName() objectForKey: @"Subject"] unsignedIntValue];
    maxLines = maxLines ? maxLines : DEFAULTMAXLINES;
    [subjectField setMaxLines:maxLines];
    
    NSFormatter *addressFormatter = [[GIAddressFormatter alloc] init];
    [toField setFormatter:addressFormatter];
    [addressFormatter release];
    
    // target/action for profile popup:
    [profileButton setTarget:self];
    [profileButton setAction:@selector(switchProfile:)];
    
    [self setupProfilePopUpButton];
    [self selectProfile: [self profile]];
}

- (void) updateHeaders
/*" Updates headers so that they are set to the values in headerFields. "*/
{
    NSEnumerator *enumerator;
    NSString *fieldName;
        
    // header fields
    enumerator = [headerFields keyEnumerator];
    while (fieldName = [enumerator nextObject])
    {
        // filter header fields that are not common:
        if ([headerOrder() containsObject:fieldName])
        {
            NSString *fieldContent = [headerFields objectForKey:fieldName];
            
            if ([fieldContent length])
            {
                [[self headerTextFieldWithFieldName:fieldName] setStringValue:fieldContent];
            }
            else
            {
                if ([self hasHeaderTextFieldWithFieldName:fieldName])
                {
                    [[self headerTextFieldWithFieldName:fieldName] setStringValue: @""];
                }
            }
        }
    }
    
#warning TODO: reenable newsgroup support here
    /*
    // Handle "Newsgroups" key:
    {
        NSString *ngValue = [headerFields objectForKey: @"Newsgroups"];
        if ([ngValue length]) {
            NSString* toValue = [headerFields objectForKey: @"To"];
            // Append newsgroups back to "To" cell, if necessary:
            [[self formCellWithFieldName: @"To"] setStringValue: toValue ? [NSString stringWithFormat: @"%@, %@", toValue, ngValue] : ngValue];
        }
    }
    
    // account info
    {
        NSArray*allSMTPAccounts;
        NSEnumerator *enumerator;
        OPMessageAccount *SMTPAccount;
        
        [accountPopup removeAllItems];
        
        allSMTPAccounts = [[OPMessageAccountManager sharedInstance] accountsForDomain:OPASMTP];
        
        enumerator = [allSMTPAccounts objectEnumerator];
        while (SMTPAccount = [enumerator nextObject]) {
            if (![SMTPAccount boolForKey: OPADISABLED]) {
                NSString *title = [SMTPAccount nameForDisplay];
                [accountPopup addItemWithTitle: title];
                [[accountPopup lastItem] setRepresentedObject: [SMTPAccount objectForKey: OPAUniqueId]];
            }
        }
    }
     */
}

- (void) takeValuesFromHeaderFields
/*" Takes values from ui header fields into the header fields dictionary. "*/
{
    NSEnumerator *enumerator;
    NSString *headerName;
    
    enumerator = [headerTextFieldsForName keyEnumerator];
    while (headerName = [enumerator nextObject])
    {
        NSString *fieldContent = [[headerTextFieldsForName objectForKey:headerName] stringValue];
        
        if ([fieldContent length])
        {
            [headerFields setObject: fieldContent forKey:headerName];
        }
        else
        {
            [headerFields removeObjectForKey:headerName];
        }
    }
}

- (BOOL) isAddressListField: (NSString*) fieldName
/*" Returns YES if the given field (non-localized!) is an address field. NO otherwise. "*/
{
    // Idea: do it via the tag instead?
    return ( ([fieldName caseInsensitiveCompare: @"to"])
        || ([fieldName caseInsensitiveCompare: @"from"])
        || ([fieldName caseInsensitiveCompare: @"reply-to"])
        || ([fieldName caseInsensitiveCompare: @"cc"])
        || ([fieldName caseInsensitiveCompare: @"bcc"]) )
    ? YES : NO;
}

- (OPSizingTextField *)createTextFieldWithFieldName: (NSString*) aFieldName
/*" Creates a new OPSizingTextField for the given field name aFieldName. It is inserted in the window by respecting the header ordering (as defined by -headerOrder). "*/
{
    OPSizingTextField *result;
    NSTextField *caption;
    NSString *displayNameForHeaderField;
    int i;
    unsigned maxLines;
    OPSizingTextField *predecessor = nil;
    float topY;
    NSRect predecessorFrame;
    NSRect frame;
        
    // search for predecessor (the new entry should be placed behind a predecessor):
    for (i = [headerOrder() indexOfObject:aFieldName] - 1; i >= 0; i--)
    {
        if ((predecessor = [headerTextFieldsForName objectForKey: [headerOrder() objectAtIndex:i]])) break;
    }
    
    if (! predecessor) predecessor = bottomTextField;
        
    // get the localized Name:
    displayNameForHeaderField = NSLocalizedString(aFieldName, @"Message header name (Subject, From, etc.)");
    
    // calculate position (frame) for new field and provide space for it:    
    predecessorFrame = [predecessor frame];
    
    topY = predecessorFrame.origin.y - 8; // gap

    // configuring text field:
    result = [[[OPSizingTextField alloc] initWithFrame: [hiddenTextFieldPrototype frame]] autorelease];
    frame = [result frame];
    frame.origin.y = topY - frame.size.height;
    [result setFrame:frame];
    [result setNextKeyView: [predecessor nextKeyView]];
    [result setAutoresizingMask: [hiddenTextFieldPrototype autoresizingMask]];  
    maxLines = [[maxLinesForCalendarName() objectForKey:aFieldName] unsignedIntValue];
    maxLines = maxLines ? maxLines : DEFAULTMAXLINES;
    [result setMaxLines:maxLines];
    
    [predecessor setNextKeyView:result];

    // configuring the caption:
    caption = [[[NSTextField alloc] initWithFrame: [hiddenCaptionPrototype frame]] autorelease];
    frame = [caption frame];
    frame.origin.y = topY - frame.size.height - 3; // center positionsa
    [caption setFrame:frame];
    [caption setStringValue: [displayNameForHeaderField stringByAppendingString: @":"]];
    [caption setAlignment:NSRightTextAlignment];
    [caption setEditable: NO];
    [caption setBezeled: NO];
    [caption setBackgroundColor: [NSColor windowBackgroundColor]];
    [caption setAutoresizingMask: [hiddenCaptionPrototype autoresizingMask]];
    
    // moving other views down:
    [[predecessor superview] moveSubviewsWithinHeight:topY verticallyBy:-1 * ([result frame].size.height + 8)];
    
    // insert the field and caption
    [[predecessor superview] addSubview:result];
    [[predecessor superview] addSubview:caption];

    if (predecessor == bottomTextField) bottomTextField = result;
    
    // if address entry field set formatter
    if ([self isAddressListField:aFieldName])
    {
        NSFormatter *addressFormatter = [[GIAddressFormatter alloc] init];
        [result setFormatter:addressFormatter];
        [addressFormatter release];
    }
    
    return result;
}

- (BOOL)hasHeaderTextFieldWithFieldName: (NSString*) aFieldName
{
    return [headerTextFieldsForName objectForKey:aFieldName] != nil;
}

- (OPSizingTextField *)headerTextFieldWithFieldName: (NSString*) aFieldName
/*" Returns a OPSizingTextField for the given field name. The form order is respected. "*/
{
    OPSizingTextField *result;
    
    result = [headerTextFieldsForName objectForKey:aFieldName];
    
    if (! result)
    {
        result = [self createTextFieldWithFieldName:aFieldName];
        [headerTextFieldsForName setObject: result forKey:aFieldName];
    }
    
    return result;
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
    NSTextField *sender = [aNotification object];
    
    if ([sender isKindOfClass:[NSTextField class]] && [[sender formatter] isKindOfClass:[GIAddressFormatter class]]) 
    {
        NSString* addressList = [sender stringValue];
        NSArray* components = [addressList componentsSeparatedByString: @","];
        NSEnumerator* enumerator = [components objectEnumerator];
        NSString*component;
        
        while (component = [enumerator nextObject])
        {
            if ([[component addressFromEMailString] length])
            {
                [GIAddressFormatter addToLRUMailAddresses: [component stringByRemovingSurroundingWhitespace]];
            }
        }
    }
}

@end

#import <AddressBook/AddressBook.h>
#import "ABPerson+Convenience.h"

@implementation GIMessageEditorController (TokenFieldDelegate)

- (NSArray*) tokenField: (NSTokenField*) tokenField completionsForSubstring: (NSString*) substring indexOfToken:(int)tokenIndex indexOfSelectedItem:(int *)selectedIndex
{
    NSMutableArray* result = [NSMutableArray array];

    ABSearchElement* searchElementEmailAddress = [ABPerson searchElementForProperty:kABEmailProperty label: nil key:nil value:substring comparison:kABPrefixMatchCaseInsensitive];
    //ABSearchElement* searchElementFirstname = [ABPerson searchElementForProperty:kABFirstNameProperty label: nil key:nil value:substring comparison:kABPrefixMatchCaseInsensitive];
    //ABSearchElement* searchElementLastname = [ABPerson searchElementForProperty:kABLastNameProperty label: nil key:nil value:substring comparison:kABPrefixMatchCaseInsensitive];
    
    NSArray* searchResult = [[ABAddressBook sharedAddressBook] recordsMatchingSearchElement:searchElementEmailAddress];

    NSEnumerator* enumerator = [searchResult objectEnumerator];
	id record;
    while (record = [enumerator nextObject]) {
        if ([record isKindOfClass: [ABPerson class]]) // only persons (not groups!) at this time
        {
            ABPerson* person   = record;
            NSString* fullname = [person fullname];
            ABMultiValue* emails = [person valueForProperty: kABEmailProperty];
            int i;
            NSString *entryCandidate = nil;
            
            for (i = 0; i < [emails count]; i++) {
                if ([fullname length]) {
                    entryCandidate = [NSString stringWithFormat: @"%@ (%@)", [emails valueAtIndex:i], fullname];
                }
                else
                {
                    entryCandidate = [person email];
                }
                
                if ([entryCandidate hasPrefix: substring]) [result addObject: entryCandidate];
            }
        }
    }
        
    NSArray* r = [result sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    return [r count] ? r : nil;
}

/*
-(NSArray*) tokenField: (NSTokenField*) tokenField shouldAddObjects:(NSArray*) tokens atIndex:(unsigned)index
{
    return [NSArray array];
}
*/

@end

@implementation GIMessageEditorController (ToolbarDelegate)

- (void) awakeToolbar
{
    NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier: @"MessageEditorToolbar"];
    
    [toolbar setDelegate:self];
    [toolbar setAllowsUserCustomization: YES];
    [toolbar setAutosavesConfiguration: YES];

    [toolbar toolbarItems:&toolbarItems defaultIdentifiers:&defaultIdentifiers forToolbarNamed: @"editor"];
    [toolbarItems retain];
    [defaultIdentifiers retain];
        
    [window setToolbar:toolbar];
}

- (void) deallocToolbar
{
    [[window toolbar] release];
    [toolbarItems release];
    [defaultIdentifiers release];
}

- (BOOL)validateToolbarItem: (NSToolbarItem*) theItem
{
    return [self validateSelector: [theItem action]];
}

- (NSToolbarItem *)toolbar: (NSToolbar*) toolbar itemForItemIdentifier: (NSString*) itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
    return [NSToolbar toolbarItemForItemIdentifier:itemIdentifier fromToolbarItemArray:toolbarItems];
}

- (NSArray*) toolbarDefaultItemIdentifiers: (NSToolbar*) toolbar
{
    return defaultIdentifiers;
}

- (NSArray*) toolbarAllowedItemIdentifiers: (NSToolbar*) toolbar
{
    static NSArray* allowedItemIdentifiers = nil;
    
    if (! allowedItemIdentifiers) {
        NSEnumerator* enumerator;
        NSToolbarItem* item;
        NSMutableArray* allowed;
        
        allowed = [NSMutableArray arrayWithCapacity: [toolbarItems count] + 5];
        
        enumerator = [toolbarItems objectEnumerator];
        while (item = [enumerator nextObject]) {
            [allowed addObject: [item itemIdentifier]];
        }
        
        [allowed addObjectsFromArray: [NSArray arrayWithObjects:NSToolbarSeparatorItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier, NSToolbarSpaceItemIdentifier, NSToolbarCustomizeToolbarItemIdentifier, nil]];
        
        allowedItemIdentifiers = [allowed copy];
    }
    
    return allowedItemIdentifiers;
}

@end
