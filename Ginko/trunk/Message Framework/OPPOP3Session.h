/*
 $Id: OPPOP3Session.h,v 1.13 2004/11/26 22:06:30 westheide Exp $

 Copyright (c) 2002, 2005 by Axel Katerbau. All rights reserved.

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
 */

#import <Foundation/Foundation.h>

@class OPStream;
@class OPInternetMessage;

typedef enum _OPPOP3State {
    DISCONNECTED = 0,
    AUTHORIZATION,
    TRANSACTION,
    UPDATE,
    DIRTY_ABORTED
} OPPOP3State;

@interface OPPOP3Session : NSObject
{
    @private OPStream *_stream;              /*" Stream for POP3 communication "*/
    @private id _delegate;                   /*" Delegate "*/
    @private int _maildropSize;              /*" Number of messages in POP3 maildrop "*/
    @private int _currentPosition;           /*" Current message 'cursor' "*/
    @private int _state;                     /*" Current session state (see OPPOP3State) "*/
    @private BOOL _shouldStop;               /*" Flag to gracefully stop running commands"*/
    @private NSMutableArray *_messageInfo;   /*" Maps message numbers (index) to infos "*/
    @private NSString *_autosaveName;        /*" Name used for autosaving UIDLs "*/
    @private NSString *_username;            /*" The username for authentication "*/
    @private NSString *_password;            /*" The password for authentication "*/
}

/*" Initialization "*/
- (id)initWithStream: (OPStream*) aStream andDelegate:(id)anObject;
- (id)initWithStream: (OPStream*) aStream username: (NSString*) username
         andPassword: (NSString*) password;

/*" Session life cycle "*/
- (void) openSession;
- (void) closeSession;
- (void) abortSession;
- (void) setShouldStop;

/*" Maildrop info "*/
- (int)currentPosition;
- (void) resetCurrentPosition;
- (void) setCurrentPosition:(int)aPosition;
- (int)maildropSize;
- (NSString*) UIDLForPosition:(int)aPosition;

/*" UIDL Autosaving "*/
- (void) setAutosaveName: (NSString*) aName;
- (NSString*) autosaveName;

/*" Misc "*/
- (NSString*) peekMessageIdOfNextMessage;
- (void) keepAlive;

@end

@interface OPPOP3Session (OPMessageProducer)
- (NSData*) nextTransferData;
- (void) skipNextMessage;
- (long)peekSizeOfNextMessage;
@end

@interface OPPOP3Session (OPCleaning)
- (void) cleanUp;
@end

/*" reason has details for the exception "*/
extern NSString *OPPOP3SessionException;

extern NSString *OPPOP3AuthenticationFailedException;

@protocol OPPOP3SessionDelegate
- (NSString*) usernameForPOP3Session: (OPPOP3Session*) aSession;
/*" Required. Returns the username for use with the given POP3Session aSession.
    POP3Session sends this method paired with %{-passwordForPOP3Session:}. "*/

- (NSString*) passwordForPOP3Session: (OPPOP3Session*) aSession;
/*" Required. Returns the password for use with the given POP3Session aSession.
    POP3Session sends this method paired with %{-usernameForPOP3Session:}."*/

- (BOOL)shouldTryAuthenticationMethod: (NSString*) authenticationMethod inPOP3Session: (OPPOP3Session*) aSession;
/*" Optional. Returns whether the given POP3Session aSession should try the authentication type given
    in authenticationMethod. If not implemented at least plain text authentication is tried. "*/

- (void) authenticationMethod: (NSString*) authenticationMethod succeededInPOP3Session: (OPPOP3Session*) aSession;
/*" Optional. Informs the receiver about what authentication type succeeded. "*/

- (BOOL)shouldContinueWithOtherAuthenticationMethodAfterFailedAuthentication: (NSString*) authenticationMethod inPOP3Session: (OPPOP3Session*) aSession;
/*" Optional. Asks whether other authentication methods should be tried as the given authenticationMethod failed. "*/

//- (BOOL)APOPRequiredForPOP3Session: (OPPOP3Session*) aSession;
- (BOOL)shouldDeleteMessageWithMessageId: (NSString*) messageId date:(NSDate*) messageDate size:(long)size inPOP3Session: (OPPOP3Session*) aSession;
@end

/*" Signals the APOP authentication method. "*/
extern NSString *OPPOP3APOPAuthenticationMethod;

/*" Signals the basic USER/PASS authentication method. "*/ 
extern NSString *OPPOP3USERPASSAuthenticationMethod;
