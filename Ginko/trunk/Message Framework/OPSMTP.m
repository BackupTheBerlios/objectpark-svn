/* 
OPSMTP.m created by axel on Sat 02-Jun-2001
 
 Copyright (c) 2001, 2006 by Axel Katerbau. All rights reserved.
 
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

#import "OPSMTP.h"
#import <OPNetwork/OPSSLSocket.h>
#import <OPNetwork/NSHost+Extensions.h>
#import "NSData+Extensions.h"
#import "NSData+MessageUtils.h"
#import "NSString+MessageUtils.h"
#import <OPDebug/OPLog.h>

NSString *OPSMTPException = @"OPSMTPException";
NSString *OPBrokenSMPTServerHint = @"OPBrokenSMPTServerHint";

@interface OPSMTP (PrivateAPI)
- (void)_assertServerAcceptedCommand;
- (NSArray *)_readResponse;
- (NSString *)_pathFromAddress:(NSString *)address;
- (BOOL)_allowsPipelining;
- (BOOL)_needsAuthentication;
- (NSString *)_username;
- (NSString *)_password;
- (BOOL)_useSMTPS;
- (BOOL)_allowAnyRootCertificate;
- (BOOL)_allowExpiredCertificates;
- (void)_writeSender:(NSString *)sender;
- (void)_writeRecipient:(NSString *)recipient;
- (void)_beginBody;
- (void)_finishBody;
- (BOOL)_hasPendingResponses;
- (BOOL)_SASLAuthentication:(NSArray*) methods;
- (BOOL)__authPlainWithUsername: (NSString*) aUsername andPassword:(NSString*) aPassword;
@end

@implementation OPSMTP

//Factory Methods

+ (id)SMTPWithUsername:(NSString *)aUsername password:(NSString *)aPassword stream:(OPStream *)aStream {
    return [[[OPSMTP alloc] initWithUsername:aUsername password:aPassword stream:aStream] autorelease];
}

+ (id)SMTPWithStream:(OPStream *)aStream andDelegate:(id)anObject {
    return [[[OPSMTP alloc] initWithStream:aStream andDelegate:anObject] autorelease];
}

// Initialization and Deallocation Methods

- (void)_connect {
    NSHost *localhost;
    NSString *name;
	NSString *domain;
	NSString *responseCode;
    NSArray *response;     
    BOOL redoEHLO;
    
    if ([self _useSMTPS]) {
        //OPDebugLog(SMTPDEBUG, OPINFO, @"Using SMTPS.");
        [(OPSSLSocket*)[stream fileHandle] setAllowsAnyRootCertificate:[self _allowAnyRootCertificate]];
        [(OPSSLSocket*)[stream fileHandle] setAllowsExpiredCertificates:[self _allowExpiredCertificates]];
        
        [stream negotiateEncryption];
    }
    
    
    // read initial greeting
    [pendingResponses addObject:@"220"];
    [self _assertServerAcceptedCommand];
    
    state = Connected;
    
    // preparing logon
    localhost = [NSHost currentHost];
    if (! (name = [localhost fullyQualifiedName]) ) {
        name = [localhost name];
        domain = [NSHost localDomain];
        if ( (! [name isEqualToString:@"localhost"]) && domain )
            if (![name hasSuffix:domain])
                name = [[name stringByAppendingString: @"."] stringByAppendingString:domain];
    }
    
    @try {
        state = NonAuthenticated;
        do {
            redoEHLO = NO;  // default is only one pass of this loop
            
            // first try if it's an extended SMTP server
            //OPDebugLog1(SMTPDEBUG, OPALL, @"EHLO %@\r\n", name);
            [stream writeFormat:@"EHLO %@\r\n", name];
            response = [self _readResponse];
            responseCode = [[response objectAtIndex:0] substringToIndex:3];
            if (![responseCode isEqualToString:@"250"]) {
                if ([responseCode hasPrefix:@"5"]) {
					// EHLO doesn't work, say HELO
                    //OPDebugLog1(SMTPDEBUG, OPALL, @"HELO %@\r\n", name);
                    [stream writeFormat:@"HELO %@\r\n", name];
                    response = [self _readResponse];
                    responseCode = [[response objectAtIndex:0] substringToIndex:3];
                    if([responseCode isEqualToString:@"250"]) // okay!
                        state = Authenticated;
                }
                break; // leave loop
            } else {
				// okay, it's an extended server!                
                // parse extensions info
                NSEnumerator *lineEnum = [response objectEnumerator];
				NSString *line;
                while (line = [lineEnum nextObject]) {
                    //OPDebugLog1(SMTPDEBUG, OPINFO, @"%@", line);
                    NSArray *components = [[line substringFromIndex:4] componentsSeparatedByString:@" "];
                    NSString *key = [[components objectAtIndex: 0] uppercaseString];
                    NSArray *value =  ([components count] > 1) ? [components subarrayWithRange:NSMakeRange(1, [components count] - 1)] : [NSArray array];
                    
                    [capabilities setObject:value forKey:key];
                }
                
                // STARTTLS (must be first negotiated extension due to RFC2487, well not really true but easier :-) )
                if ((![[stream fileHandle] isEncrypted]) &&
                    ([capabilities objectForKey:@"STARTTLS"] && [[stream fileHandle] isKindOfClass:[OPSSLSocket class]])) {
                    //OPDebugLog(SMTPDEBUG, OPINFO, @"Server is capable of STARTTLS. Trying to upgrade to TLS encryption...");
                    
                    [(OPSSLSocket *)[stream fileHandle] setAllowsAnyRootCertificate:[self _allowAnyRootCertificate]];
                    [(OPSSLSocket *)[stream fileHandle] setAllowsExpiredCertificates:[self _allowExpiredCertificates]];
                    
                    [stream writeFormat:@"STARTTLS\r\n"];
                    response = [self _readResponse];
                    //OPDebugLog1(SMTPDEBUG, OPALL, @"Servers reply to STARTTLS comand: %@", [response objectAtIndex:0]);
                    
                    responseCode = [[response objectAtIndex:0] substringToIndex:3];
					
                    if ([responseCode isEqualToString:@"220"]) {
                        //OPDebugLog(SMTPDEBUG, OPINFO, @"Starting TLS encryption");
                        [stream negotiateEncryption]; // throws an exception on error
                        
                        // RFC2487 requires us to forget all capabilities
                        [capabilities release];
                        capabilities = [[NSMutableDictionary allocWithZone:[self zone]] init];
                        // Start again with an EHLO
                        redoEHLO = YES;
                    }
                    
                    continue;
                }
                
                // AUTH
                if (state != Authenticated) {
                    NSArray *methods = [capabilities objectForKey:@"AUTH"];
                    
                    if (methods) {
                        //OPDebugLog(SMTPDEBUG, OPINFO, @"Server supports AUTH. Trying to AUTHenticate"); 
                        if ([self _SASLAuthentication:methods]) {
                            state = Authenticated;
                        } else {
                            //OPDebugLog(SMTPDEBUG, OPWARNING, @"AUTHentication failed!");
                        }
                    } else {
                        if ([[self _password] length] != 0) {
                            //OPDebugLog(SMTPDEBUG, OPWARNING, @"Password provided but server does not support AUTHentication!");
                            
                            state = Authenticated;
						}
                    }
                }
                
            }
        }
        while (redoEHLO);
        
        //OPDebugLog(SMTPDEBUG, OPALL, @"HELO/EHLO done.");
        
        if (state != Authenticated) {
			// Other error - most likely "421 - Service not available"
            //OPDebugLog(SMTPDEBUG, OPWARNING, @"Failed SMTP init. Exception!"); 
            [NSException raise:OPSMTPException format:@"Failed to initialize SMTP connection; read \"%@\"", [response componentsJoinedByString:@" "]];
        }        
        
        } @catch (NSException *localException) {
            //OPDebugLog2(SMTPDEBUG, OPWARNING, @"Exception! name: %@ reason: %@", [localException name], [localException reason]); 
            
            if ([[localException name] isEqualToString:OPSMTPException]) {
                [localException raise];
            } else {
                NSMutableDictionary *amendedUserInfo = [NSMutableDictionary dictionaryWithDictionary:[localException userInfo]];
                
                // We can also get here if the extensions "parsing" fails; if for example
                // a line in the response contains less than 4 characters. This is also
                // counted as a broken server that doesn't really understand EHLO...
                [amendedUserInfo setObject:@"YES" forKey:OPBrokenSMPTServerHint];
                [[NSException exceptionWithName:[localException name] 
										 reason:[localException reason] 
									   userInfo:amendedUserInfo] raise];
            }
		}
}

- (void)_commonInits
{
    pendingResponses = [[NSMutableArray allocWithZone:[self zone]] init];
    capabilities = [[NSMutableDictionary allocWithZone:[self zone]] init];
    
    // try to get to Ready state
    state = Disconnected;
}

- (id)initWithStream:(OPStream *)aStream andDelegate:(id)anObject
{
    if (self = [super init]) {
        _delegate = anObject;
        stream = [aStream retain];
        [self _commonInits];
        [self _connect];
    }
    return self;  
}

- (id)initWithUsername:(NSString *)aUsername password:(NSString *)aPassword stream:(OPStream *)aStream
{
    NSParameterAssert(aStream);
    
    if (self = [super init])
    {        
        stream = [aStream retain];
        username = [aUsername retain];
        password = [aPassword retain];
        [self _commonInits];
        [self _connect];
    }
    return self;
}

/*" Sends message with given parameters. Raises an exception if the message could not be sent. "*/
- (void) sendPlainText: (NSString*) body 
				  from: (NSString*) from 
					to: (NSArray*) recipients
			   subject: (NSString*) subject
		   moreHeaders: (NSDictionary*) userHeaders 
{
	NSParameterAssert([from length]);
	NSParameterAssert([[recipients lastObject] length]);
	NSParameterAssert([subject length]);
	NSParameterAssert([body length]);
	
	NSMutableData* transferData = [NSMutableData data];
	NSMutableDictionary* headers = userHeaders ? [userHeaders mutableCopy] : [NSMutableDictionary dictionary];
	NSCalendarDate* date = [NSCalendarDate date];
	NSString* bundleName = [[[[NSBundle bundleForClass: [self class]] bundlePath] lastPathComponent] stringByDeletingPathExtension];
	if (!bundleName) bundleName = @"OPMessage";
	
	// Set necessary headers:
	[headers setValue: subject forKey: @"Subject"];
	[headers setValue: from forKey: @"From"];
	[headers setValue: date forKey: @"Date"];
	[headers setValue: [recipients componentsJoinedByString: @","] forKey: @"To"];
	[headers setValue: @"text/plain; charset=\"iso-8859-1\"; format=\"flowed\"" forKey: @"Content-Type"];
	[headers setValue: @"1.0" forKey: @"MIME-Version"];

	[headers setValue: [NSString stringWithFormat: @"<%@%u>", bundleName, ABS([date timeIntervalSince1970]+[body hash])] forKey: @"Message-ID"];

	if (![body canBeConvertedToEncoding: NSASCIIStringEncoding]) {
		// Signal that we are using the 8th bit:
		[headers setValue: @"8bit" forKey: @"Content-Transfer-Encoding"];
	}
	
	NSEnumerator* headerEnumerator = [headers keyEnumerator];
	NSString* headerName;
	
	// Make header data 7-bit clean:
	while (headerName = [headerEnumerator nextObject]) {
		NSString* headerValue = [headers objectForKey: headerName];
		
		if ([headerValue isKindOfClass: [NSCalendarDate class]]) {
			[(NSCalendarDate*)headerValue setTimeZone: [NSTimeZone timeZoneWithName: @"GMT"]];
			headerValue = [(NSCalendarDate*)headerValue descriptionWithCalendarFormat: @"%a, %d %b %Y %H:%M:%S %z"]; 
		}
		
		if (![headerValue canBeConvertedToEncoding: NSASCIIStringEncoding]) {
			// Do header encoding here
			if ([headerValue canBeConvertedToEncoding: NSISOLatin1StringEncoding]) {
				// Example:
				// Subject: =?iso-8859-1?Q?Steuererkl=E4rung_am_Macintosh_und_PC_leicht_gemacht!?=
				NSData* data = [[headerValue dataUsingEncoding: NSISOLatin1StringEncoding]  encodeHeaderQuotedPrintable];
				headerValue = [NSString stringWithFormat: @"=?iso-8859-1?Q?%@?=", [NSString stringWithData: data encoding: NSASCIIStringEncoding]];
			} else {
				// Raise Exception
			}
		}
				
		NSString* headerLine = [NSString stringWithFormat: @"%@: %@\r\n", headerName, headerValue];
		
		NSAssert2([headerLine length]<950, @"Encoded Header '%@' too long: %u characters.", headerName, [headerLine length]);

		[transferData appendData: [headerLine dataUsingEncoding: NSASCIIStringEncoding]];
	}
	
	[transferData appendData: [@"\r\n" dataUsingEncoding: NSASCIIStringEncoding]]; // could be more efficient
	
	body = [body stringWithCanonicalLinebreaks];
	body = [body stringByEncodingFlowedFormat];
	
	[transferData appendData: [body dataUsingEncoding: NSISOLatin1StringEncoding]];
	
	NSLog(@"PlainTextEmail:\n%@", [NSString stringWithData: transferData encoding: NSISOLatin1StringEncoding]);
		
	[self sendTransferData: transferData from: from to: recipients];
	
}

- (void)dealloc
{
    [self quit];
    
    [username release];
    [password release];
    [stream release];
    [capabilities release];
    
    [super dealloc];
}

// Methods of Interface OPMessageConsumer

/* Returns YES if the receiver will accept at least one EDInternetMessage for consumption. NO otherwise.*/
- (BOOL)willAcceptMessage {
    return state == Authenticated;
}

- (BOOL)handles8BitBodies {
    return [capabilities objectForKey:@"8BITMIME"] != nil;
}

/*" Sends message transfer data from sender to recipients. 
Raises an exception if the message could not be sent. "*/
- (void)sendTransferData:(NSData *)data from:(NSString *)sender to:(NSArray *)recipients {
    NSEnumerator *enumerator;
    NSString *recipient;
    
    if ([self _allowsPipelining]) {
        [self _writeSender:sender];
        
        enumerator = [recipients objectEnumerator];
        while (recipient = [enumerator nextObject])
            [self _writeRecipient:recipient];
        
        [self _beginBody];
        
        // check if all in order
        while ([self _hasPendingResponses])
            [self _assertServerAcceptedCommand];
    } else {
		// No pipelining:
        
        [self _writeSender:sender];
        [self _assertServerAcceptedCommand];
        
        enumerator = [recipients objectEnumerator];
        while (recipient = [enumerator nextObject]) {
            [self _writeRecipient:recipient];
            [self _assertServerAcceptedCommand];
        }
        
        [self _beginBody];
        [self _assertServerAcceptedCommand];
    }
    
    [stream setEscapesLeadingDots:YES];
    [stream writeData:data];
    [stream setEscapesLeadingDots:NO];
    [self _finishBody];
    [self _assertServerAcceptedCommand];
}

/*
- (void)sendMailWithHeaders:(NSDictionary *)userHeaders andBody:(NSString *)body {
//    EDPlainTextContentCoder	 *textCoder;
    NSEnumerator			 *headerFieldNameEnum;
    NSString				 *sender, *newRecipients, *headerFieldName;
    NSMutableArray 			 *recipients;
    NSArray					 *authors;
    NSData					 *transferData;
    id						 headerFieldBody;
    
    recipients = [NSMutableArray array];
    if((newRecipients = [userHeaders objectForKey:@"To"]) != nil)
        [recipients addObjectsFromArray:[newRecipients addressListFromEMailString]];
    if((newRecipients = [userHeaders objectForKey:@"CC"]) != nil)
        [recipients addObjectsFromArray:[newRecipients addressListFromEMailString]];
    if((newRecipients = [userHeaders objectForKey:@"BCC"]) != nil)
        [recipients addObjectsFromArray:[newRecipients addressListFromEMailString]];
    if([recipients count] == 0)
        [NSException raise:NSInvalidArgumentException format:@"-[%@ %@]: No recipients in header list.", NSStringFromClass(isa), NSStringFromSelector(_cmd)];
    
    if((sender = [userHeaders objectForKey:@"Sender"]) == nil)
    {
        authors = [[userHeaders objectForKey:@"From"] addressListFromEMailString];
        if([authors count] == 0)
            [NSException raise:NSInvalidArgumentException format:@"-[%@ %@]: No sender or from field in header list.", NSStringFromClass(isa), NSStringFromSelector(_cmd)];
        if([authors count] > 1)
            [NSException raise:NSInvalidArgumentException format:@"-[%@ %@]: Multiple from addresses and no sender field in header list.", NSStringFromClass(isa), NSStringFromSelector(_cmd)];
        sender = [authors objectAtIndex:0];
    }
    
    body = [body stringWithCanonicalLinebreaks];
        
    textCoder = [[[EDPlainTextContentCoder alloc] initWithText:body] autorelease];
    [textCoder setDataMustBe7Bit:([stream handles8BitBodies] == NO)];

    // only plain text
    bodyPart = message = [textCoder message];
    
    headerFieldNameEnum = [userHeaders keyEnumerator];
    while((headerFieldName = [headerFieldNameEnum nextObject]) != nil)
    {
        headerFieldBody = [userHeaders objectForKey:headerFieldName];
        if([headerFieldName caseInsensitiveCompare:@"BCC"] != NSOrderedSame)
        {
            if([headerFieldBody isKindOfClass:[NSDate class]])
                headerFieldBody = [[EDDateFieldCoder encoderWithDate:headerFieldBody] fieldBody];
            else
                // Doesn't do any harm as all fields that shouldn't have MIME words
                // should only have ASCII (in which case no transformation will take
                // place.) A case of garbage in, garbage out...
                headerFieldBody = [[EDTextFieldCoder encoderWithText:headerFieldBody] fieldBody];
            [message addToHeaderFields:[EDObjectPair pairWithObjects:headerFieldName:headerFieldBody]];
        }
    }
    
    transferData = [message transferData];
    
    //    [stream setStringEncoding:[NSString stringEncodingForMIMEEncoding:charset]];
    [self _sendMail:transferData from:sender to:recipients usingStream:stream];
}
*/

- (void)quit
/*" Logs off from the SMTP server. "*/
{
	if (state != Disconnected) {
        [stream writeString:@"QUIT\r\n"];
		//OPDebugLog(SMTPDEBUG, OPINFO, @"OPSMTP: shutting down encryption in dealloc");
		[stream shutdownEncryption];
		state = Disconnected;
	}
	
	[stream release]; stream = nil;
}

@end

@implementation OPSMTP (PrivateAPI)

- (void)_assertServerAcceptedCommand
{    
    if (! [pendingResponses count])
        [NSException raise: NSInternalInconsistencyException format:@"-[%@ %@]: No pending responses.", NSStringFromClass(isa), NSStringFromSelector(_cmd)];
    
    NSString *expectedCode = [[[pendingResponses objectAtIndex:0] retain] autorelease];
    [pendingResponses removeObjectAtIndex:0];
    NSArray *response = [self _readResponse];
    if (! [[response objectAtIndex:0] hasPrefix:expectedCode])
        [NSException raise: OPSMTPException format:@"Unexpected SMTP response code; expected %@, read \"%@\"", expectedCode, [response componentsJoinedByString:@" "]];
}

- (NSArray *)_readResponse
{
    NSString *partialResponse;
    NSMutableArray *response;
    
    response = [NSMutableArray array];
    do {
        partialResponse = [stream availableLine];
        [response addObject:partialResponse];
    } while ([partialResponse characterAtIndex:3] == '-');
    
    return response;
}

- (NSString *)_pathFromAddress:(NSString *)address
{
    NSString *path;
    
    if (! [address hasPrefix:@"<"])
        path = [NSString stringWithFormat:@"<%@>", address];
    else
        path = address;
    
    return path;
}

- (BOOL)_allowsPipelining
{
    return [capabilities objectForKey: @"PIPELINING"] != nil;
}

- (BOOL)_needsAuthentication
{
    return ([capabilities objectForKey: @"AUTH"] != nil) && (state != Authenticated);
}

- (NSString *)_username
{
    if (username) {
        return username;
    }
    
    if ([_delegate respondsToSelector:@selector(usernameForSMTP:)]) {
        return [_delegate usernameForSMTP:self];
    }
    
    return nil;
}

- (NSString *)_password
{
    if (password) {
        return password;
    }
    
    if ([_delegate respondsToSelector:@selector(passwordForSMTP:)]) {
        return [_delegate passwordForSMTP:self];
    }
    
    return nil;
}

- (BOOL)_useSMTPS
{
    if ([_delegate respondsToSelector:@selector(useSMTPS:)]) {
        return [_delegate useSMTPS:self];
    }
    
    return NO;
}

- (BOOL)_allowAnyRootCertificate
{
    if ([_delegate respondsToSelector:@selector(allowAnyRootCertificateForSMTP:)]) {
        return [_delegate allowAnyRootCertificateForSMTP:self];
    }
    
    return NO;
}

- (BOOL)_allowExpiredCertificates
{
    if ([_delegate respondsToSelector:@selector(allowExpiredCertificatesForSMTP:)]) {
        return [_delegate allowExpiredCertificatesForSMTP:self];
    }
    
    return NO;
}

- (void)_writeSender:(NSString *)sender
{
    if([self handles8BitBodies])
        [stream writeFormat:@"MAIL FROM:%@ BODY=8BITMIME\r\n", [self _pathFromAddress:sender]];
    else
        [stream writeFormat:@"MAIL FROM:%@\r\n", [self _pathFromAddress:sender]];
    [pendingResponses addObject:@"250"];
}

- (void)_writeRecipient:(NSString *)recipient
{
    OPDebugLog(GISMTP, OPINFO, @"RCPT TO:%@ (orig: %@)", [self _pathFromAddress:recipient], recipient);
    [stream writeFormat:@"RCPT TO:%@\r\n", [self _pathFromAddress:recipient]];
    [pendingResponses addObject:@"250"];
}

- (void)_beginBody
{
    [stream writeString:@"DATA\r\n"];
    [pendingResponses addObject:@"354"];
}

- (void)_finishBody
{
    [stream writeString:@"\r\n.\r\n"];
    [pendingResponses addObject:@"250"];
}

- (BOOL)_hasPendingResponses
{
    return [pendingResponses count] > 0;
}

- (BOOL)_SASLAuthentication:(NSArray *)authMethods
{
    NSString *method;
    NSString *aUsername, *aPassword;
    NSEnumerator *methods = [authMethods reverseObjectEnumerator];
    
    aUsername = [self _username];
    aPassword = [self _password];
    
    // assume to be authenticated, if password is nil
    if ([aPassword length] == 0)
        return YES;
    
    while (method = [methods nextObject]) {
        method = [method uppercaseString];
        
        if ([method isEqualToString: @"PLAIN"])
            return [self __authPlainWithUsername: aUsername andPassword:aPassword];
        // add other AUTH methods here
    }
    
    //OPDebugLog(SMTPDEBUG, OPWARNING, @"OOPS! We have a problem. No known AUTH method is supported!");
    return NO;
}


// PLAIN authentication only
- (BOOL)__authPlainWithUsername:(NSString *)aUsername andPassword:(NSString *)aPassword
{        
    NSData *sesame;
    NSString *authString;
    
    NSParameterAssert(aUsername && aPassword);
    
    // initiate auth        
    sesame = [[[NSString stringWithFormat: @"\0%@\0%@", aUsername, aPassword] dataUsingEncoding: NSUTF8StringEncoding] encodeBase64];
    
    authString = [NSString stringWithFormat: @"AUTH PLAIN %@", [NSString stringWithCString: [sesame bytes] length: [sesame length]]];
    
    //OPDebugLog1(SMTPDEBUG, OPALL, @"auth string = (%@)", authString);
    [stream writeString: authString];
    
    [pendingResponses addObject: @"235"];
    
    [self _assertServerAcceptedCommand];
    
    return YES;
}

@end
