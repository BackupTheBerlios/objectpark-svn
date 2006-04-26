/*
 $Id: OPPOP3Session.m,v 1.29 2004/11/26 22:06:29 westheide Exp $

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

#import "OPPOP3Session.h"
#import "OPInternetMessage.h"
#import <OPNetwork/OPStream+SSL.h>
#import <OPDebug/OPLog.h>
#import "NSData+OPMD5.h"
#import "NSString+MessageUtils.h"
#import "GIApplication.h"
#import "NSApplication+OPExtensions.h"

NSString *OPPOP3SessionException = @"OPPOP3SessionException";
NSString *OPPOP3AuthenticationFailedException = @"OPPOP3AuthenticationFailedException";
NSString *OPPOP3APOPAuthenticationMethod = @"OPPOP3APOPAuthenticationMethod";
NSString *OPPOP3USERPASSAuthenticationMethod = @"OPPOP3USERPASSAuthenticationMethod";

#define UIDLsDir @"Infos for UIDLs"

@interface OPPOP3Session (Authentication)
- (void)_authenticationWithServerGreeting:(NSString *)serverGreeting;
- (void)_userPassAuthentication;
- (void)_APOPAuthenticationWithServerGreeting:(NSString *)serverGreeting;
- (NSString *)_digestForServerTimestamp:(NSString *)serverTimestamp andSecret:(NSString *)secret;
@end

@interface OPPOP3Session (UIDL)
- (void)_takeInfoFromTransferData:(NSData *)transferData forPosition:(int)position;
- (void)_addMessageSizesToMessageInfo;
- (int)_synchronizeUIDLs;
- (void)_autosaveUIDLs;
@end

@interface OPPOP3Session (ServerResponseAndSimpleCommands)
- (BOOL)_isOKResponse:(NSString *)aResponse;
- (NSString *)_readOKForCommand:(NSString *)command;
- (NSString *)_serverGreeting;
- (int)_maildropSize;
- (NSData *)_transferDataAtPosition:(int)position;
- (NSData *)_headerDataAtPosition:(int)position;
- (void)_gatherStatsIfNeeded;
@end

@implementation OPPOP3Session
/*" Handles a POP3 client session to a POP3 server. Uses a delegate for UIDL handling,
    deletion of old messages, etc. The session will be automatically closed when the
    instance is dealloced. "*/

- (id)init
/*" Throws exception. Use the designated initWithStream init method instead. "*/
{
    [self dealloc];
    [NSException raise:OPPOP3SessionException format: @"Use of wrong init method. Use the designated -initWithStream:andDelegate: init method instead."];
    return nil;
}

- (id)initWithStream:(OPStream *)aStream andDelegate:(id)anObject
/*" Initializes the session for use with stream aStream and delegate anObject. The use
    of an delegate is optional but one doesn't get the benefits. "*/
{
    [super init];

    _stream = [aStream retain];
    [_stream setEscapesLeadingDots:YES];
    _delegate = anObject; 	// weak reference
    _maildropSize = -1;		// not requested yet
    _currentPosition = 1;	// first message
    _state = DISCONNECTED;
    _shouldStop = NO;
    
    return self;
}

- (id)initWithStream:(OPStream *)aStream username:(NSString *)username andPassword:(NSString *)password
/*" Alternative initializer. The initialized instance does not neccessarily need
    a delegate. "*/
{
    [super init];

    _stream = [aStream retain];
    [_stream setEscapesLeadingDots:YES];
    _username = [username retain];
    _password = [password retain];
    _maildropSize = -1;		// not requested yet
    _currentPosition = 1;	// first message
    _state = DISCONNECTED;
    _shouldStop = NO;
    
    return self;
}

- (void)dealloc
/*" Closes the session and releases ivars. "*/
{
    [self closeSession];
    [_stream release];
    [_messageInfo release];
    [_autosaveName release];
    [_username release];
    [_password release];
    
    [super dealloc];
}

- (void)openSession
/*" Logs the user in and lets the session enter TRANSACTION state. Throws an %{OPPOP3SessionException} otherwise. "*/
{
    NSAssert(_state == DISCONNECTED, @"POP3 session can not be opened (DISCONNECTED state required).");

    [self _authenticationWithServerGreeting:[self _serverGreeting]];
}

- (void)closeSession
/*" Closes session by sending the QUIT command if needed. "*/
{
    if ((_state != UPDATE) && (_state != DISCONNECTED))
    {
        // stream needs closing
        [self _readOKForCommand:@"QUIT"];
        [self _autosaveUIDLs];
        _state = UPDATE;
    }
}

- (void)abortSession
/*" Aborts the session with rollback of DELEs. "*/
{
    if (_state == TRANSACTION)
    {
        // stream needs closing
        [self _readOKForCommand:@"RSET"];
        [self _readOKForCommand:@"QUIT"];
        _state = UPDATE;
    } else {
        _state = DIRTY_ABORTED;
    }
}

- (void) setShouldStop
/*"Makes the currently running command abort gracefully (currently only used to abort the cleanup)."*/
{
    _shouldStop = YES;
}

- (int)currentPosition
/*" Returns the position of the maildrop 'cursor'. "*/
{
    return _currentPosition;
}

- (void) setCurrentPosition:(int)aPosition
/*" Sets the current postion in the mail drop to aPosition. Raises if out of bounds. "*/
{
    NSParameterAssert((aPosition > 0) && (aPosition <= [self maildropSize]));
    _currentPosition = aPosition;
}

- (void) resetCurrentPosition
/*" Resets the current position to the first message in the mail drop. "*/
{
    _currentPosition = 1;
}

- (int)maildropSize
/*" Returns the number of messages in the maildrop (POP3 server). -1 if unknown. "*/
{
    [self _gatherStatsIfNeeded];
    
    return _maildropSize;
}

- (NSString *)UIDLForPosition:(int)aPosition
/*" Returns the UIDL for the given position aPosition, if the server supports
UIDL. nil otherwise. "*/
{
    NSString *command;
    NSString *result;

    [self _gatherStatsIfNeeded];
    
    command = [@"UIDL" stringByAppendingFormat:@"%d", aPosition];
    NS_DURING
        [self _readOKForCommand:command]; 	// try to use UIDL command
    NS_HANDLER
        if (NSDebugEnabled) NSLog(@"UIDL command not understood by POP3 server.", self);
        while ([_stream availableLine]) ; 	// do nuffin but eat the whole response
        return nil;				// UIDL command not understood.
    NS_ENDHANDLER

    result = [[[_stream availableLine] componentsSeparatedByString: @" "] objectAtIndex:2];
    while ([_stream availableLine]) ; 	// eat the rest response
    
    return result;
}

- (NSString *)peekMessageIdOfNextMessage
{
    NSString *result = nil;

    [self _gatherStatsIfNeeded];
    
    if ( (_currentPosition <= _maildropSize) && (_currentPosition > 0) )
    {
        NSMutableDictionary *infoDict = [_messageInfo objectAtIndex:_currentPosition - 1];
        result = [infoDict objectForKey:@"messageId"];

        if (NSDebugEnabled) NSLog(@"peeking id of message #%d in %@", _currentPosition, self);

        if (! result) // try to get info from message
        {
            [self _takeInfoFromTransferData:[self _headerDataAtPosition:_currentPosition] forPosition:_currentPosition];
            
            result = [infoDict objectForKey:@"messageId"];
        }
    }

    return result;
}

- (void)keepAlive
/*" Sends a command to the server to prevent the connection from timing out. "*/
{
    if (NSDebugEnabled) NSLog(@"sending 'keep alive' for %@", [self description]);
	
	[_stream writeLine:@"CAPA"];
	NSString *line;
	do
	{
		line = [_stream availableLine];
	}
	while (line);
}

- (void)setAutosaveName:(NSString *)aName
{
    [aName retain];
    [_autosaveName release];
    _autosaveName = aName;
}

- (NSString *)autosaveName
{
    return _autosaveName;
}

- (NSString *)description
/*" Overridden from %{NSObject}. Returns string containing information about the receiver. "*/
{
    return [NSMutableString stringWithFormat:@"<POP3Session %@: stream %@>", [super description], _stream]; 
}

@end

@implementation OPPOP3Session (OPMessageProducer)

- (NSData *)nextTransferData
{
    NSData *result;
    
    [self _gatherStatsIfNeeded];
    
    if (result = [self _transferDataAtPosition:_currentPosition])
    {
        [self _takeInfoFromTransferData:result forPosition:_currentPosition];
        _currentPosition += 1;
    }
        
    return result;
}

// POP3 specific
- (long)peekSizeOfNextMessage
/*" POP3 specific extension of the %{OPMessageProducer} protocol.
    Returns the size of the next message without consuming the next message. "*/
{
    [self _gatherStatsIfNeeded];

    if ( (_currentPosition <= _maildropSize) && (_currentPosition > 0) )
    {
        return [[[_messageInfo objectAtIndex:_currentPosition - 1] objectForKey:@"size"] longValue];
    }
    return -1;
}

- (void)skipNextMessage
/*" Skips the next message. "*/
{
    _currentPosition += 1;
}

@end

@implementation OPPOP3Session (OPCleaning)

- (void) cleanUp
{
    if (NSDebugEnabled) NSLog(@"Starting cleanup...");
    
    [self _gatherStatsIfNeeded];
    
    if ([_delegate respondsToSelector:@selector(shouldDeleteMessageWithMessageId:date:size:inPOP3Session:)])
    {
        int i;
        for (i = 1; (i <= (_currentPosition - 1)) && (!_shouldStop); i++)
        {
            NSMutableDictionary *infoDict = [_messageInfo objectAtIndex:i - 1];
            NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
            long size = [[infoDict objectForKey:@"size"] longValue];
            NSString *messageId = [infoDict objectForKey:@"messageId"];
            NSDate *date = [NSDate dateWithString:[[infoDict objectForKey:@"date"] description]];

            //if (NSDebugEnabled) NSLog(@"Cleaning message #%d in %@", i, self);
            
            if ( (! date) && (! messageId) ) // try to get info from message
            {
                OPInternetMessage *message;
                NSData *headerData = [self _headerDataAtPosition:i];
                NS_DURING
                    message = [[[OPInternetMessage alloc] initWithTransferData:headerData] autorelease];

                    if (message)
                    {
                        [self _takeInfoFromTransferData:headerData forPosition:i];

                        messageId = [infoDict objectForKey:@"messageId"];
                        date = [NSDate dateWithString:[[infoDict objectForKey:@"date"] description]];
                    }
                NS_HANDLER
                    ;
                NS_ENDHANDLER
            }
            
            if ([_delegate shouldDeleteMessageWithMessageId:messageId date:date size:size inPOP3Session:self])
            {
                [self _readOKForCommand:[NSString stringWithFormat:@"DELE %d", i]];

                // remove message from message info
                [_messageInfo replaceObjectAtIndex:i - 1 withObject:[NSNull null]];
            }
            
            [pool release];            
        }
    }
    if (NSDebugEnabled) NSLog(@"Cleanup finished.");
}

@end

@implementation OPPOP3Session (Authentication)

- (void)_authenticationWithServerGreeting:(NSString *)serverGreeting
/*" Tries authentication with the server. Raises if no selected (by the delegate) method succeeds. "*/
{
    BOOL shouldContinue = YES;
    NSMutableArray *triedMethods;

    triedMethods = [NSMutableArray array];
    
	NSDate *dateBefore = [NSDate date];

    // get username and password
    if (! _username)
    {
        if ([_delegate respondsToSelector:@selector(usernameForPOP3Session:)])
        {
            _username = [[_delegate usernameForPOP3Session:self] retain];
        }
        else
        {
            [NSException raise:OPPOP3SessionException format:@"Delegate either not set or does not implement the required OPPOP3SessionDelegate method -usernameForPOP3Session: (POP3Session: %@).", self];
        }
    }

    if (! _password)
    {
        if ([_delegate respondsToSelector:@selector(passwordForPOP3Session:)])
        {
            _password = [[_delegate passwordForPOP3Session:self] retain];
        }
        else
        {
            [NSException raise:OPPOP3SessionException format:@"Delegate either not set or does not implement the required OPPOP3SessionDelegate method -passwordForPOP3Session: (POP3Session: %@).", self];
        }
    }
    	
    if ((! _username) || (! _password))
    {
        [NSException raise:OPPOP3SessionException format:@"username and/or password is/are nil in POP3Session %@.", self];
    }

	if ([dateBefore timeIntervalSinceNow] < (NSTimeInterval)-5.0)
	{;
		// as gathering username and password may have taken a long time, test if server is still listening:
		@try
		{
			[self keepAlive];
		}
		@catch (NSException *localException)
		{
			[NSException raise:OPPOP3SessionException format:@"Timeout in POP3Session %@.", self];	
		}
	}
	
    // APOP
    NS_DURING
    {
        if ([_delegate respondsToSelector:@selector(shouldTryAuthenticationMethod:inPOP3Session:)])
        {
            if ([_delegate shouldTryAuthenticationMethod:OPPOP3APOPAuthenticationMethod inPOP3Session:self])
            {
                [triedMethods addObject:@"APOP"];
                [self _APOPAuthenticationWithServerGreeting:serverGreeting];
            }
            
            if (NSDebugEnabled) NSLog(@"APOP succeeded for POP3Session %@.", self);

            if ([_delegate respondsToSelector:@selector(authenticationMethod:succeededInPOP3Session:)])
            {
                [_delegate authenticationMethod:OPPOP3APOPAuthenticationMethod succeededInPOP3Session:self];
            }
        }
    }
    NS_HANDLER
    {
        if (NSDebugEnabled) NSLog(@"APOP failed for POP3Session %@.", self);
        
        [triedMethods addObject:[NSString stringWithFormat: @"APOP failed (%@)", [localException reason]]];
        
        if ([_delegate respondsToSelector:@selector(shouldContinueWithOtherAuthenticationMethodAfterFailedAuthentication:inPOP3Session:)])
        {
            shouldContinue = [_delegate shouldContinueWithOtherAuthenticationMethodAfterFailedAuthentication:OPPOP3APOPAuthenticationMethod inPOP3Session:self];
        }
    }
    NS_ENDHANDLER

    // USER/PASS
    if (shouldContinue && _state != TRANSACTION)
    {
        NS_DURING
            // use plain vanilla username & password authentication
        {
            if ([_delegate respondsToSelector:@selector(shouldTryAuthenticationMethod:inPOP3Session:)])
            {
                if ([_delegate shouldTryAuthenticationMethod:OPPOP3USERPASSAuthenticationMethod inPOP3Session:self])
                {
                    [triedMethods addObject:@"Plain"];
                    [self _userPassAuthentication];
                }
            }
            else
            {
                [triedMethods addObject:@"Plain"];
                [self _userPassAuthentication];
            }

            if (NSDebugEnabled) NSLog(@"USER/PASS succeeded for POP3Session %@.", self);
            
            if ([_delegate respondsToSelector:@selector(authenticationMethod:succeededInPOP3Session:)])
            {
                [_delegate authenticationMethod:OPPOP3USERPASSAuthenticationMethod succeededInPOP3Session:self];
            }
        }
        NS_HANDLER
        {
            if (NSDebugEnabled) NSLog(@"USER/PASS failed for POP3Session %@.", self);
            
            [triedMethods addObject:[NSString stringWithFormat:@"Plain failed (%@)", [localException reason]]];
            
            if ([_delegate respondsToSelector:@selector(shouldContinueWithOtherAuthenticationMethodAfterFailedAuthentication:inPOP3Session:)])
            {
                shouldContinue = [_delegate shouldContinueWithOtherAuthenticationMethodAfterFailedAuthentication:OPPOP3USERPASSAuthenticationMethod inPOP3Session:self];
            }
        }
        NS_ENDHANDLER        
    }
    
    // clear username and password
    [_username release];
    _username = nil;
    [_password release];
    _password = nil;

    if (_state != TRANSACTION)
    {
        NSString *triedMessage;

        triedMessage = [triedMethods componentsJoinedByString:@", "];
        if (![triedMessage length])
        {
            triedMessage = @"None";
        }
        
        _state = DISCONNECTED;
        [NSException raise:OPPOP3AuthenticationFailedException format:@"POP3 server authentication failed. Tried %@.", triedMessage];
    }
}

- (void)_userPassAuthentication
/*" Try to authenticate via the USER and PASS authentication scheme. If
    successfull, the session is in TRANSACTION state afterwards. Raises otherwise."*/
{
    [self _readOKForCommand:[@"USER " stringByAppendingString:_username]];
    [self _readOKForCommand:[@"PASS " stringByAppendingString:_password]];
    _state = TRANSACTION;
}

- (void)_APOPAuthenticationWithServerGreeting:(NSString *)serverGreeting
/*" If successfull, the session is in TRANSACTION state afterwards. Raises otherwise. "*/
{
    NSString *serverTimestamp;

    NS_DURING
        serverTimestamp = [serverGreeting addressFromEMailString];
    NS_HANDLER
        serverTimestamp = nil;
    NS_ENDHANDLER
    
    if ([serverTimestamp length])	// if timestamp available
    {
        NSString *digest;

        digest = [self _digestForServerTimestamp:serverTimestamp andSecret:_password];
        // respond to challenge
        [self _readOKForCommand:[[[@"APOP " stringByAppendingString:_username]
                     stringByAppendingString:@" "] stringByAppendingString:digest]];
        _state = TRANSACTION;
    }
}

- (NSString *)_digestForServerTimestamp:(NSString *)serverTimestamp andSecret:(NSString *)secret
/*" Returns the client response for the server challenge serverTimestamp and the secret. "*/
{
    NSMutableString *result;
    NSData *md5Input;
    int di;
    md5_state_t state;
    md5_byte_t digest[16];

    serverTimestamp = [[@"<" stringByAppendingString:serverTimestamp] stringByAppendingString:@">"];
    md5Input = [[serverTimestamp stringByAppendingString:secret] dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];

    md5_init(&state);
    md5_append(&state, (const md5_byte_t *)[md5Input bytes], [md5Input length]);
    md5_finish(&state, digest);

    result = [NSMutableString string];

    for (di = 0; di < 16; di++)
        [result appendFormat: @"%02x", digest[di]];

    return result;
}

@end

@implementation OPPOP3Session (UIDL)

- (void)_setMessageInfo:(NSMutableArray *)anArray
{
    [anArray retain];
    [_messageInfo release];
    _messageInfo = anArray;
}

- (void)_takeInfoFromTransferData:(NSData *)transferData forPosition:(int)position
{
    OPInternetMessage *message = nil;
    
    @try
    {
        message = [[OPInternetMessage alloc] initWithTransferData:transferData];
        // save message info
        NSMutableDictionary *infoDict = [_messageInfo objectAtIndex:position - 1];
        NSString *messageId = [message messageId];
        NSDate *date = [message date];
        
        if (messageId)
            [infoDict setObject:messageId forKey:@"messageId"];
        
        if (date)
            [infoDict setObject:date forKey:@"date"];
    }
    @finally
    {
        [message release];
    }
}

- (void)_addMessageSizesToMessageInfo
/*" Issues the LIST command and collects the size info in the message info dicts. "*/
{
    NSString *response;
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    NS_DURING
        [self _readOKForCommand:@"LIST"]; 	// try to use LIST command

        response = [_stream availableLine];
        while (response)
        {
            NSArray *components = [response componentsSeparatedByString: @" "];
            NSAssert([components count] > 1, @"components not right -> bug in OPNetwork because dotted line prob");
            NSDecimalNumber *sizeNumber = [[NSDecimalNumber alloc] initWithString:
                [components objectAtIndex:1]];
            int messageNumber = [[components objectAtIndex:0] intValue];

            [[_messageInfo objectAtIndex:messageNumber - 1] setObject:sizeNumber forKey:@"size"];

            [sizeNumber release];
            response = [_stream availableLine];
        };
    NS_HANDLER
        if (NSDebugEnabled) NSLog(@"LIST command failed on POP3 server.");
    NS_ENDHANDLER

    [pool release];
}

- (int)_synchronizeUIDLs
/*" Returns the message number of the last message from a previous session
    if calculatable or 0 if not. "*/
{
    NSString *response, *UIDLFromLastPosition = nil;
    NSDictionary *infoForUIDL = nil;
    NSAutoreleasePool *pool;
    int result = 0, i;

    pool = [[NSAutoreleasePool alloc] init];

    if ([_autosaveName length])
    {
        infoForUIDL = [NSDictionary dictionaryWithContentsOfFile:[[[[NSApplication sharedApplication] applicationSupportPath] stringByAppendingPathComponent:UIDLsDir] stringByAppendingPathComponent:_autosaveName]];
        
        UIDLFromLastPosition = [[NSUserDefaults standardUserDefaults] stringForKey:
            [@"OPPOP3Session lastUIDL " stringByAppendingString:_autosaveName]];
        
        if (NSDebugEnabled) NSLog(@"%@: Read UIDL %@ for last position from user defaults.", self, UIDLFromLastPosition);
    } else {
        if (NSDebugEnabled) NSLog(@"%@: No UIDLs read from user defaults. No autosave name given.", self);
    }

    // create info array
    [self _setMessageInfo:[NSMutableArray arrayWithCapacity:_maildropSize]];
    for (i = 0; i < _maildropSize; i++)
        [_messageInfo addObject:[NSMutableDictionary dictionaryWithCapacity:4]];
    
    NS_DURING
        [self _readOKForCommand:@"UIDL"]; 	// try to use UIDL command
    NS_HANDLER
        if (NSDebugEnabled) NSLog(@"UIDL command not understood by POP3 server.");
        while ([_stream availableLine]) ; 	// do nuffin but eat the whole response
        [pool release];
        return 0;				// UIDL command not understood.
    NS_ENDHANDLER

    NS_DURING
        while (response = [_stream availableLine])
        {
            NSMutableDictionary *infoDict;
            NSArray *components;
            NSString *UIDL;
            int messageNumber;

            components = [response componentsSeparatedByString:@" "];
            NSAssert([components count] > 1, @"components not right -> bug in OPNetwork because dotted line prob");
            messageNumber = [[components objectAtIndex:0] intValue];
            UIDL = [components objectAtIndex:1];

            infoDict = [_messageInfo objectAtIndex:messageNumber - 1];

            if ([UIDL length])
            {
                NSDictionary *contentFromInfoForUIDL;

                // add info from infoForUIDL if present
                [infoDict setObject:UIDL forKey:@"UIDL"];
                if (contentFromInfoForUIDL = [infoForUIDL objectForKey:UIDL])
                    [infoDict addEntriesFromDictionary:contentFromInfoForUIDL];
            }
            
            if ([UIDLFromLastPosition isEqualToString:UIDL])
            {
                if (result == 0)
                {
                    result = messageNumber;
                    if (NSDebugEnabled) NSLog(@"%@: Position %d for last UIDL found.", self, messageNumber);
                }
                else
                {
                    if (NSDebugEnabled) NSLog(@"%@: CAUTION! An additional position %d for last UIDL found.", self, messageNumber);
                }
            }
        };
    NS_HANDLER
        if (NSDebugEnabled) NSLog(@"%@: Error while retrieving UIDLs from POP3 server.", self);
    NS_ENDHANDLER

    [pool release];

    if (result == 0)
    {
        if (NSDebugEnabled) NSLog(@"%@: No position for last UIDL found. Defaulting to first message of maildrop.", self);
    }
    
    return result;
}

- (void)_autosaveUIDLs
{
    if (([_autosaveName length]) && (_maildropSize != -1))
    {
        NSMutableDictionary *infoForUIDL = [NSMutableDictionary dictionaryWithCapacity:_maildropSize];
        NSUserDefaults *defaults;
        NSString *key;
        int i, UIDLPosition;
        
        defaults = [NSUserDefaults standardUserDefaults];

        key = [@"OPPOP3Session lastUIDL " stringByAppendingString:_autosaveName];
        [defaults removeObjectForKey:key];

        // find last position with a valid message info (current position may be DELEted)
        UIDLPosition = _currentPosition;
        while ((UIDLPosition > 1) && ([NSNull null] == [_messageInfo objectAtIndex:UIDLPosition - 2]))
        {
            UIDLPosition -= 1;
        }        

        if (UIDLPosition > 1)
        {
            NSString *UIDLFromLastPosition;
            
            if (UIDLFromLastPosition = [[_messageInfo objectAtIndex:UIDLPosition - 2] objectForKey:@"UIDL"])
            {
                [defaults setObject:UIDLFromLastPosition forKey:key];
                if (NSDebugEnabled) NSLog(@"%@: Saved last position UIDL %@ to user defaults.", self, UIDLFromLastPosition);
            }
            else
            {
                if (NSDebugEnabled) NSLog(@"%@: Saved NO last position UIDL to user defaults. Not found.", self);
            }
        }

        key = [@"OPPOP3Session infoForUIDL " stringByAppendingString:_autosaveName];
        [defaults removeObjectForKey:key];
        for (i = 0; i < _maildropSize; i++)
        {
            NSMutableDictionary *info;
            NSString *UIDL;

            info = [_messageInfo objectAtIndex:i];

            if ((id)info != [NSNull null])
            {
                NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
                
                info = [[info mutableCopy] autorelease];
                UIDL = [info objectForKey:@"UIDL"];

                if (! UIDL) // no UIDLs given...nothing more to do
                    return;

                [infoForUIDL setObject:info forKey:UIDL];

                [info removeObjectForKey:@"UIDL"];	// not needed...why waste space?
                
                [pool release];
            }
        }
        
        NSString *dir = [[[NSApplication sharedApplication] applicationSupportPath] stringByAppendingPathComponent:UIDLsDir];
        if (![[NSFileManager defaultManager] fileExistsAtPath:dir])
        {
            [[NSFileManager defaultManager] createDirectoryAtPath:dir attributes: nil];
        }
        
        NSString *path = [dir stringByAppendingPathComponent:_autosaveName];
        
        if (![infoForUIDL writeToFile:path atomically: YES])
        {
            NSLog(@"Could not save UIDLs for %@", _autosaveName);
        }
    }
}

@end


@implementation OPPOP3Session (ServerResponseAndSimpleCommands)

- (BOOL)_isOKResponse:(NSString *)aResponse
{
    return [aResponse hasPrefix:@"+OK"];
}

- (NSString *)_readOKForCommand:(NSString *)command
{
    NSString *line = nil;

    if (command)
    {
        [_stream writeLine:command];
    }
    
    line = [_stream availableLine];
    if (! [self _isOKResponse:line])
    {
        // prevent printing of password
        if ([command hasPrefix:@"PASS "])
        {
            command = @"PASS ********";
        }
        
        [NSException raise:OPPOP3SessionException
                    format:@"The command \"%@\" was rejected by the POP3 server: \"%@\"", command, line];
    }
    
    return line;
}

- (NSString *)_serverGreeting
/*" Reads the initial greeting with the optional timestamp for APOP.
    Returns the server's greeting. After leaving this method the session is in
    AUTHORIZATION state. Throws an %{OPPOP3SessionException} otherwise. "*/
{
    NSString *response = nil;
    // Read greeting with optional timestamp:
    @try 
	{
        response = [self _readOKForCommand:nil];
    } 
	@catch (NSException *localException) 
	{
        [NSException raise:OPPOP3SessionException
                    format:@"The POP3 server does not respond (with a 'server greeting')."];
    }
        
    // Go in AUTHORIZATION state:
    _state = AUTHORIZATION;
    return response;
}

- (int)_maildropSize
/*" Returns the number of messages in the POP3 maildrop (server). Requires TRANSACTION state. "*/
{
    NSString *response;
    NSAssert(_state == TRANSACTION, @"POP3 session is not in TRANSACTION state");

    response = [self _readOKForCommand:@"STAT"];
    return [[NSDecimalNumber decimalNumberWithString:[[response componentsSeparatedByString:@" "] objectAtIndex:1]] intValue];
}

- (NSData *)_transferDataAtPosition:(int)position
{
    NSData *transferData = nil;

    if ( (position <= _maildropSize) && (position > 0) ) 
	{
		NSString *command = [NSString stringWithFormat:@"RETR %d", position];
        @try 
		{
            [self _readOKForCommand:command];
            transferData = [_stream availableTextData];
        } @catch (NSException *localException) 
		{
            if (NSDebugEnabled) NSLog(@"Warning: POP3 server fails for command '%@': %@", command, localException);
		}
    }
    return transferData;
}

- (NSData *)_headerDataAtPosition:(int)position
{
    NSData *headerData = nil;

    if ( (position <= _maildropSize) && (position > 0) ) 
	{;
        @try 
		{
            [self _readOKForCommand:[NSString stringWithFormat:@"TOP %d 0", position]];
            headerData = [_stream availableTextData];
        } 
		@catch (NSException *localException) 
		{
            if (NSDebugEnabled) NSLog(@"POP3 server does not understand the optional TOP command. Using RETR instead.");
            headerData = [self _transferDataAtPosition:position];
        }
    }
    return headerData;
}

- (void)_gatherStatsIfNeeded
{
    if (_maildropSize == -1)
    {
        if (_state == DISCONNECTED)
            [self openSession];

        NSAssert(_state == TRANSACTION, @"Cannot gather stats because error entering TRANSACTION state");
        
        _maildropSize = [self _maildropSize];
        _currentPosition = [self _synchronizeUIDLs] + 1;
        [self _addMessageSizesToMessageInfo];
    }
}

@end
