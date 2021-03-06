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
#import "NSString+Extensions.h"
#import <Foundation/NSDebug.h>
#include <sasl.h>
#include <saslutil.h>
#import "OPSASL.h"

NSString *OPSMTPException = @"OPSMTPException";
NSString *OPSMTPAuthenticationFailedException = @"OPSMTPAuthenticationFailedException";
NSString *OPBrokenSMPTServerHint = @"OPBrokenSMPTServerHint";
NSString *OPSMTPServerDoesNotLikeRecipientNotification = @"OPSMTPServerDoesNotLikeRecipientNotification";

@interface OPSMTP (PrivateAPI)
- (void)assertServerAcceptedCommand;
- (NSArray *)readResponse;
- (NSString *)pathFromAddress:(NSString *)address;
- (BOOL)allowsPipelining;
//- (BOOL)needsAuthentication;
- (NSString *)username;
- (NSString *)password;
- (BOOL)useSMTPS;
- (BOOL)allowAnyRootCertificate;
- (BOOL)allowExpiredCertificates;
- (void)writeSender:(NSString *)sender;
- (void)writeRecipient:(NSString *)recipient;
- (void)beginBody;
- (void)finishBody;
- (BOOL)hasPendingResponses;
- (BOOL)SASLAuthentication:(NSArray *)methods;
//- (BOOL)__authPlainWithUsername:(NSString *)aUsername andPassword:(NSString *)aPassword;
- (void)freeSASLResources;
@end

@implementation OPSMTP

//Factory Methods

+ (id)SMTPWithUsername:(NSString *)aUsername password:(NSString *)aPassword stream:(OPStream *)aStream hostname:(NSString *)aHostname useSMTPS:(BOOL)shouldUseSMTPS allowAnyRootCertificate:(BOOL)shouldAllowAnyRootCertificate allowExpiredCertificates:(BOOL)shouldAllowExpiredCertificates
/*" See -initWithUsername:password:stream:hostname:useSMTPS for details. "*/
{
    return [[[OPSMTP alloc] initWithUsername:aUsername password:aPassword stream:aStream hostname:aHostname useSMTPS:shouldUseSMTPS allowAnyRootCertificate:shouldAllowAnyRootCertificate allowExpiredCertificates:shouldAllowExpiredCertificates] autorelease];
}

+ (id)SMTPWithStream:(OPStream *)aStream andDelegate:(id)anObject 
{
    return [[[OPSMTP alloc] initWithStream:aStream andDelegate:anObject] autorelease];
}

// Initialization and Deallocation Methods

- (void)doHELOWithDomain:(NSString *)domain
{
	NSString *responseCode;
    NSArray *response;     

	//OPDebugLog1(SMTPDEBUG, OPALL, @"HELO %@\r\n", domain);
	[stream writeFormat:@"HELO %@\r\n", domain];
	response = [self readResponse];
	responseCode = [[response objectAtIndex:0] substringToIndex:3];
	if([responseCode isEqualToString:@"250"]) // okay!
	{
		state = Authenticated;
	}
}

- (void)connect 
{
    NSHost *localhost;
    NSString *name;
	NSString *domain;
	NSString *responseCode;
    NSArray *response;     
    BOOL redoEHLO;
    
    if ([self useSMTPS]) 
	{
        //OPDebugLog(SMTPDEBUG, OPINFO, @"Using SMTPS.");
        [(OPSSLSocket *)[stream fileHandle] setAllowsAnyRootCertificate:[self allowAnyRootCertificate]];
        [(OPSSLSocket *)[stream fileHandle] setAllowsExpiredCertificates:[self allowExpiredCertificates]];
        
        [stream negotiateEncryption];
    }
    
    // read initial greeting
    [pendingResponses addObject:@"220"];
    [self assertServerAcceptedCommand];
    
    state = Connected;
    
    // preparing logon
    localhost = [NSHost currentHost];
    if (! (name = [localhost fullyQualifiedName]) ) 
	{
        name = [localhost name];
        domain = [NSHost localDomain];
        if ( (! [name isEqualToString:@"localhost"]) && domain )
            if (![name hasSuffix:domain])
                name = [[name stringByAppendingString: @"."] stringByAppendingString:domain];
    }
    
    @try 
	{
        state = NonAuthenticated;
		
		// use only HELO if no password and no username given
		if (![[self username] length])
		{
			[self doHELOWithDomain:name];
		}
		else
		{
			do 
			{
				redoEHLO = NO;  // default is only one pass of this loop
				
				// first try if it's an extended SMTP server
				//OPDebugLog1(SMTPDEBUG, OPALL, @"EHLO %@\r\n", name);
				[stream writeFormat:@"EHLO %@\r\n", name];
				response = [self readResponse];
				responseCode = [[response objectAtIndex:0] substringToIndex:3];
				if (![responseCode isEqualToString:@"250"]) 
				{
					if ([responseCode hasPrefix:@"5"]) 
					{
						[self doHELOWithDomain:name];
					}
					break; // leave loop
				} 
				else 
				{
					// okay, it's an extended server!                
					// parse extensions info
					NSEnumerator *lineEnum = [response objectEnumerator];
					NSString *line;
					while (line = [lineEnum nextObject]) 
					{
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
						
						[(OPSSLSocket *)[stream fileHandle] setAllowsAnyRootCertificate:[self allowAnyRootCertificate]];
						[(OPSSLSocket *)[stream fileHandle] setAllowsExpiredCertificates:[self allowExpiredCertificates]];
						
						[stream writeFormat:@"STARTTLS\r\n"];
						response = [self readResponse];
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
					if (state != Authenticated) 
					{
						NSArray *methods = [capabilities objectForKey:@"AUTH"];
						
						if (methods) 
						{
							//OPDebugLog(SMTPDEBUG, OPINFO, @"Server supports AUTH. Trying to AUTHenticate"); 
							if ([self SASLAuthentication:methods]) 
							{
								state = Authenticated;
							} 
							else 
							{
								[NSException raise:OPSMTPAuthenticationFailedException format:@"SMTP Authentication failed. Please check login and password."];
								
								//OPDebugLog(SMTPDEBUG, OPWARNING, @"AUTHentication failed!");
							}
						} 
						else 
						{
							if ([[self password] length] != 0) 
							{
								//OPDebugLog(SMTPDEBUG, OPWARNING, @"Password provided but server does not support AUTHentication!");
								
								state = Authenticated;
							}
						}
					}
				}
			}
			while (redoEHLO);
        }
		
        //OPDebugLog(SMTPDEBUG, OPALL, @"HELO/EHLO done.");
        
        if (state != Authenticated) 
		{
			// Other error - most likely 421 - Service not available
            //OPDebugLog(SMTPDEBUG, OPWARNING, @"Failed SMTP init. Exception!"); 
            [NSException raise:OPSMTPException format:@"Failed to initialize SMTP connection; read '%@'", [response componentsJoinedByString:@" "]];
        }        
	} 
	@catch (id localException) 
	{
		//OPDebugLog2(SMTPDEBUG, OPWARNING, @"Exception! name: %@ reason: %@", [localException name], [localException reason]); 
            
		if ([[localException name] isEqualToString:OPSMTPException]) 
		{
			@throw;
		} 
		else 
		{
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

- (void)commonInits
{
    pendingResponses = [[NSMutableArray allocWithZone:[self zone]] init];
    capabilities = [[NSMutableDictionary allocWithZone:[self zone]] init];
    
    // try to get to Ready state
    state = Disconnected;
}

- (id)initWithStream:(OPStream *)aStream andDelegate:(id)anObject
{
    if (self = [super init]) 
	{
        _delegate = anObject;
        stream = [aStream retain];
        [self commonInits];
        //[self connect]; may throw! Caller should do it!
    }
    return self;  
}

- (id)initWithUsername:(NSString *)aUsername password:(NSString *)aPassword stream:(OPStream *)aStream hostname:(NSString *)aHostname useSMTPS:(BOOL)shouldUseSMTPS allowAnyRootCertificate:(BOOL)shouldAllowAnyRootCertificate allowExpiredCertificates:(BOOL)shouldAllowExpiredCertificates
/*" If the use of a simple SMTP server (HELO) without any authentication is required, 
	use nil (or a zero length string) for username. "*/
{
    NSParameterAssert(aStream);
    
    if (self = [super init])
    {        
        stream = [aStream retain];
        username = [aUsername retain];
        password = [aPassword retain];
		hostname = [aHostname retain];
		useSMTPS = shouldUseSMTPS;
		allowAnyRootCertificate = shouldAllowAnyRootCertificate;
		allowExpiredCertificates = shouldAllowExpiredCertificates;
		
        [self commonInits];
        [self connect];
    }
    return self;
}

/*" Sends message with given parameters. Raises an exception if the message could not be sent. Only supports languages encodeable in ISO-Latin-1. "*/
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
	NSMutableDictionary* headers = userHeaders ? [[userHeaders mutableCopy] autorelease] : [NSMutableDictionary dictionary];
	NSCalendarDate* date = [NSCalendarDate date];
	NSString* bundleName = [[[[NSBundle bundleForClass: [self class]] bundlePath] lastPathComponent] stringByDeletingPathExtension];
	if (!bundleName) bundleName = @"OPMessage";
	
	// Set necessary headers:
	[headers setValue: subject forKey: @"Subject"];
	[headers setValue: from forKey: @"From"];
	[headers setValue: date forKey: @"Date"];
	[headers setValue: [recipients componentsJoinedByString: @","] forKey: @"To"];
	[headers setValue: @"text/plain; charset=\"iso-8859-1\"; format=\"flowed\"; delsp=\"yes\"" forKey: @"Content-Type"];
	[headers setValue: @"1.0" forKey: @"MIME-Version"];

	[headers setValue: [NSString stringWithFormat: @"<%@#%x%x>", bundleName, ABS([date timeIntervalSince1970]+[body hash]), rand()] forKey: @"Message-ID"];

	if (![body canBeConvertedToEncoding: NSASCIIStringEncoding]) {
		// Signal that we are using the 8th bit:
		[headers setValue:@"8bit" forKey:@"Content-Transfer-Encoding"];
	}
	
	NSEnumerator *headerEnumerator = [headers keyEnumerator];
	NSString *headerName;
	
	// Make header data 7-bit clean:
	while (headerName = [headerEnumerator nextObject]) 
	{
		NSString *headerValue = [headers objectForKey:headerName];
		
		if ([headerValue isKindOfClass: [NSCalendarDate class]]) 
		{
			[(NSCalendarDate *)headerValue setTimeZone: [NSTimeZone timeZoneWithName:@"GMT"]];
			headerValue = [(NSCalendarDate*)headerValue descriptionWithCalendarFormat:@"%a, %d %b %Y %H:%M:%S %z"]; 
		}
		
		if (![headerValue canBeConvertedToEncoding:NSASCIIStringEncoding]) 
		{
			// Do header encoding here
			if ([headerValue canBeConvertedToEncoding:NSISOLatin1StringEncoding]) 
			{
				// Example:
				// Subject: =?iso-8859-1?Q?Steuererkl=E4rung_am_Macintosh_und_PC_leicht_gemacht!?=
				NSData *data = [[headerValue dataUsingEncoding: NSISOLatin1StringEncoding] encodeHeaderQuotedPrintable];
				headerValue = [NSString stringWithFormat:@"=?iso-8859-1?Q?%@?=", [NSString stringWithData:data encoding:NSASCIIStringEncoding]];
			} else {
				// Raise Exception
			}
		}
				
		NSString *headerLine = [NSString stringWithFormat: @"%@: %@\r\n", headerName, headerValue];
		
		NSAssert2([headerLine length]<950, @"Encoded Header '%@' too long: %u characters.", headerName, [headerLine length]);

		[transferData appendData:[headerLine dataUsingEncoding: NSASCIIStringEncoding]];
	}
	
	[transferData appendData:[@"\r\n" dataUsingEncoding:NSASCIIStringEncoding]]; // could be more efficient
	
	body = [body stringWithCanonicalLinebreaks];
	body = [body stringByEncodingFlowedFormatUsingDelSp:YES];
	body = [body stringWithCanonicalLinebreaks];

	[transferData appendData:[body dataUsingEncoding:NSISOLatin1StringEncoding]];
	
	if (NSDebugEnabled) NSLog(@"PlainTextEmail:\n%@", [NSString stringWithData:transferData encoding:NSISOLatin1StringEncoding]);
		
	[self sendTransferData:transferData from:from to:recipients];
}

- (void) dealloc
{
    [self quit];
    
	[self freeSASLResources];
	
    [username release];
    [password release];
	[hostname release];
	
    [stream release];
    [capabilities release];
    
    [super dealloc];
}

// Methods of Interface OPMessageConsumer

/* Returns YES if the receiver will accept at least one EDInternetMessage for consumption. NO otherwise.*/
- (BOOL)willAcceptMessage 
{
    return state == Authenticated;
}

- (BOOL)handles8BitBodies 
{
    return [capabilities objectForKey:@"8BITMIME"] != nil;
}

/*" Sends message transfer data from sender to recipients. 
Raises an exception if the message could not be sent. "*/
- (void)sendTransferData:(NSData *)data from:(NSString *)sender to:(NSArray *)recipients 
{
    NSEnumerator *enumerator;
    NSString *recipient;
    
    if ([self allowsPipelining]) 
	{
        [self writeSender:[sender addressFromEMailString]];
		[self assertServerAcceptedCommand];
				
        enumerator = [recipients objectEnumerator];
        while (recipient = [enumerator nextObject])
            [self writeRecipient:[recipient addressFromEMailString]];
        
        // check if all in order
		unsigned i = 0;
        while ([self hasPendingResponses])
		{
			@try
			{
				[self assertServerAcceptedCommand];
			}
			@catch (id localException)
			{
				[[NSNotificationCenter defaultCenter] postNotificationName:OPSMTPServerDoesNotLikeRecipientNotification object:self userInfo:[NSDictionary dictionaryWithObject:[recipients objectAtIndex:i] forKey:@"Recipient"]];
				@throw;
			}
			
			i += 1;
		}
		
        [self beginBody];
		[self assertServerAcceptedCommand];
    } 
	else 
	{
		// No pipelining:
        
        [self writeSender:[sender addressFromEMailString]];
        [self assertServerAcceptedCommand];
        
        enumerator = [recipients objectEnumerator];
        while (recipient = [enumerator nextObject]) 
		{
            [self writeRecipient:[recipient addressFromEMailString]];
			@try
			{
				[self assertServerAcceptedCommand];
			}
			@catch (id localException)
			{
				[[NSNotificationCenter defaultCenter] postNotificationName:OPSMTPServerDoesNotLikeRecipientNotification object:self userInfo:[NSDictionary dictionaryWithObject:recipient forKey:@"Recipient"]];
				@throw;
			}
        }
        
        [self beginBody];
        [self assertServerAcceptedCommand];
    }
    
    [stream setEscapesLeadingDots:YES];
    [stream writeData:data];
    [stream setEscapesLeadingDots:NO];
    [self finishBody];
    [self assertServerAcceptedCommand];
}

- (void) quit
/*" Logs off from the SMTP server. "*/
{
	if (state != Disconnected) {
		@try {
			[stream writeString: @"QUIT\r\n"];
			//OPDebugLog(SMTPDEBUG, OPINFO, @"OPSMTP: shutting down encryption in dealloc");
			[stream shutdownEncryption];
		} @catch (id localException) {
			// ignored
		}
		state = Disconnected;
	}
	
	[stream release]; stream = nil;
}

@end

@implementation OPSMTP (PrivateAPI)

- (void)assertServerAcceptedCommand
{    
    if (! [pendingResponses count])
        [NSException raise:NSInternalInconsistencyException format:@"-[%@ %@]: No pending responses.", NSStringFromClass(isa), NSStringFromSelector(_cmd)];
    
    NSString *expectedCode = [[[pendingResponses objectAtIndex:0] retain] autorelease];
    [pendingResponses removeObjectAtIndex:0];
    NSArray *response = [self readResponse];
    if (! [[response objectAtIndex:0] hasPrefix:expectedCode])
        [NSException raise: OPSMTPException format:@"Unexpected SMTP response code; expected %@, read \"%@\"", expectedCode, [response componentsJoinedByString:@" "]];
}

- (NSArray *)readResponse
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

- (NSString *)pathFromAddress:(NSString *)address
{
    NSString *path;
    
    if (! [address hasPrefix:@"<"])
        path = [NSString stringWithFormat:@"<%@>", address];
    else
        path = address;
    
    return path;
}

- (BOOL)allowsPipelining
{
    return [capabilities objectForKey: @"PIPELINING"] != nil;
}

/*
- (BOOL)needsAuthentication
{
    return ([capabilities objectForKey: @"AUTH"] != nil) && (state != Authenticated);
}
*/

- (NSString *)username
{
    if (username) 
	{
        return username;
    }
    
    if ([_delegate respondsToSelector:@selector(usernameForSMTP:)]) 
	{
        return [_delegate usernameForSMTP:self];
    }
    
    return nil;
}

- (NSString *)password
{
    if (password) 
	{
        return password;
    }
    
    if ([_delegate respondsToSelector:@selector(passwordForSMTP:)]) 
	{
        return [_delegate passwordForSMTP:self];
    }
    
    return nil;
}

- (NSString *)hostname
{
    if (hostname) {
        return hostname;
    }
    
    if ([_delegate respondsToSelector:@selector(serverHostnameForSMTP:)]) {
        return [_delegate serverHostnameForSMTP:self];
    }
    
    return nil;
}

- (BOOL)useSMTPS
{
    if ([_delegate respondsToSelector:@selector(useSMTPS:)]) {
        return [_delegate useSMTPS:self];
    }
    
    return useSMTPS;
}

- (BOOL)allowAnyRootCertificate
{
    if ([_delegate respondsToSelector:@selector(allowAnyRootCertificateForSMTP:)]) {
        return [_delegate allowAnyRootCertificateForSMTP:self];
    }
    
    return allowAnyRootCertificate;
}

- (BOOL)allowExpiredCertificates
{
    if ([_delegate respondsToSelector:@selector(allowExpiredCertificatesForSMTP:)]) {
        return [_delegate allowExpiredCertificatesForSMTP:self];
    }
    
    return allowExpiredCertificates;
}

- (void)writeSender:(NSString *)sender
{
    if([self handles8BitBodies])
        [stream writeFormat:@"MAIL FROM:%@ BODY=8BITMIME\r\n", [self pathFromAddress:sender]];
    else
        [stream writeFormat:@"MAIL FROM:%@\r\n", [self pathFromAddress:sender]];
    [pendingResponses addObject:@"250"];
}

- (void)writeRecipient:(NSString *)recipient
{
    if (NSDebugEnabled) NSLog(@"RCPT TO:%@ (orig: %@)", [self pathFromAddress:recipient], recipient);
    [stream writeFormat:@"RCPT TO:%@\r\n", [self pathFromAddress:recipient]];
    [pendingResponses addObject:@"250"];
}

- (void)beginBody
{
    [stream writeString:@"DATA\r\n"];
    [pendingResponses addObject:@"354"];
}

- (void)finishBody
{
    [stream writeString:@"\r\n.\r\n"];
    [pendingResponses addObject:@"250"];
}

- (BOOL)hasPendingResponses
{
    return [pendingResponses count] > 0;
}

// Callback functions for SASL library

static int getsecret_func(sasl_conn_t *conn,
						  void *context,
						  int id,
						  sasl_secret_t **psecret)
{
	if (id!=SASL_CB_PASS) return SASL_FAIL; // paranoia
	
	OPSMTP *smtp = (OPSMTP *)context;
	if (![smtp isKindOfClass:[OPSMTP class]])
	{
		[NSException raise:NSGenericException format:@"Expected a OPSTMP object but got a %@ object", NSStringFromClass([smtp class])];
	}
	
	const char *UTF8Password = [[smtp password] UTF8String];
	unsigned long passwordLength = 0;
		
	if (UTF8Password)
	{
		passwordLength = strlen(UTF8Password);
	}
	
	(*psecret) = malloc(sizeof(sasl_secret_t) + passwordLength + 1);
	smtp->getsecret_func_psecret = (*psecret);
	
	(*psecret)->len = passwordLength;
	
	memcpy((*psecret)->data, UTF8Password, passwordLength);
	(*psecret)->data[passwordLength] = 0;
	
	return SASL_OK;
}

static int getauthname_func(void *context,
							int id,
							const char **result,
							unsigned *len)
{
	if (id!=SASL_CB_AUTHNAME) return SASL_FAIL; // paranoia
	
	OPSMTP *smtp = (OPSMTP *)context;
	if (![smtp isKindOfClass:[OPSMTP class]])
	{
		[NSException raise:NSGenericException format:@"Expected a OPSTMP object but got a %@ object", NSStringFromClass([smtp class])];
	}
	
	const char *UTF8Username = [[smtp username] UTF8String];
	unsigned long usernameLength = 0;
	if (UTF8Username) 
	{
		*result = strdup(UTF8Username);
		usernameLength = strlen(*result);
		smtp->getauthname_func_result = (*result);
	}
	else
	{
		(*result) = "";
	}
	
	//memcpy((void *)*result, UTF8Username, usernameLength);
	//(*result)[usernameLength] = 0;
	
	len = malloc(sizeof(unsigned));
	smtp->getauthname_func_len = len;
	
	(*len) = usernameLength;
	
	return SASL_OK;
}

- (void)freeSASLResources
{
	if (conn) sasl_dispose(&conn);

	if (getauthname_func_result) free((void *)getauthname_func_result);
	if (getauthname_func_len) free(getauthname_func_len);
	
	if (getuser_func_result) free((void *)getuser_func_result);
	if (getuser_func_len) free(getuser_func_len);

	if (getsecret_func_psecret) free(getsecret_func_psecret);
}

- (void)interaction:(int)iid :(const char *)prompt :(char **)tresult :(unsigned int *)tlen
{
//    char result[1024];
	
    if (iid == SASL_CB_PASS) 
	{
		*tresult = (char *)[[self password] UTF8String];
		*tlen = strlen(*tresult);
		return;
    } 
	else if (iid == SASL_CB_USER) 
	{
		puts("USER");
		*tresult = (char *)[[self username] UTF8String];
		*tlen = strlen(*tresult);
		return;
    } 
	else if (iid == SASL_CB_AUTHNAME) 
	{
		*tresult = (char *)[[self username] UTF8String];
		*tlen = strlen(*tresult);
		return;
    } 
	else if ((iid == SASL_CB_GETREALM) /* && (realm != NULL) */) 
	{
		[NSException raise:OPSMTPException format:@"Not supported SASL intercation SASL_CB_GETREALM."];
		//strcpy(result, realm);
    } 
	else 
	{
		[NSException raise:OPSMTPException format:@"Not supported SASL intercation."];
    }

	// never used
	/*
	*tlen = strlen(result);
	*tresult = (char *) malloc(*tlen+1); // leak!
	memset(*tresult, 0, *tlen+1);
	memcpy((char *) *tresult, result, *tlen);
	 */
}

- (void)fillin_interactions:(sasl_interact_t *)tlist
{
    while (tlist->id != SASL_CB_LIST_END)
    {
		[self interaction:tlist->id :tlist->prompt :(void *)&(tlist->result) :&(tlist->len)];
		tlist++;
    }
}

- (BOOL)SASLAuthentication:(NSArray *)authMethods
{
	static NSArray *supportedMethods = nil;
	
	if (!supportedMethods)
	{
		supportedMethods = [[NSArray alloc] initWithObjects:@"CRAM-MD5", @"LOGIN", @"PLAIN", @"ANONYMOUS", nil];
	}
	
	NSMutableArray *qualifyingMethods = [NSMutableArray array];
	NSEnumerator *enumerator = [supportedMethods objectEnumerator];
	NSString *method;
	
	while (method = [enumerator nextObject])
	{
		if ([authMethods containsObject:method])
		{
			[qualifyingMethods addObject:method];
		}
	}
	
	if ([qualifyingMethods count] == 0)
	{
		[NSException raise:OPSMTPException format:@"No supported SASL authentication method. Server supports: %@", authMethods];
	}
	
	[OPSASL initialize]; // be sure to have the SASL lib initialized
	
	/* The SASL context kept for the life of the connection */
	int result;
	
	sasl_callback_t myCallbacks[] = 
	{
	{
		SASL_CB_GETREALM, NULL, NULL  /* we'll just use an interaction if this comes up */
	}, 
	{
		SASL_CB_USER, NULL, NULL      /* we'll just use an interaction if this comes up */
	}, 
	{
		SASL_CB_AUTHNAME, &getauthname_func, self /* A mechanism should call getauthname_func if it needs the authentication name */
	}, 
	{ 
		SASL_CB_PASS, &getsecret_func, self      /* Call getsecret_func if need secret */
	}, 
	{
		SASL_CB_LIST_END, NULL, NULL
	}
	};
	
	// client new connection
	result = sasl_client_new("smtp",     // The service we are using
							 [[self hostname] UTF8String], // The fully qualified domain name of the server we're connecting to
							 NULL, NULL, // Local and remote IP address strings
							 myCallbacks,       // connection-specific callbacks
							 0,          // security flags
							 &conn);     // allocated on success
							 
	// check to see if that worked */
	if (result != SASL_OK) 
	{
		if (NSDebugEnabled) NSLog(@"sasl_client_new failed");
		return NO;
	}
						   
	sasl_interact_t *client_interact = NULL;
	const char *out, *mechusing;
	unsigned outlen;
	
	const char *mechlist = [[qualifyingMethods componentsJoinedByString:@" "] UTF8String];
	
	char out64[4096];
	
	do {
		
		result = sasl_client_start(conn,      /* the same context from
		above */ 
								 mechlist,  /* the list of mechanisms
								 from the server */
								 &client_interact, /* filled in if an
								 interaction is needed */
								 &out,      /* filled in on success */
								 &outlen,   /* filled in on success */
								 &mechusing);
		
		if (result == SASL_INTERACT)
		{
			[self fillin_interactions:client_interact];
		}
		
	} while (result == SASL_INTERACT); /* the mechanism may ask us to fill
                                               in things many times. result is 
                                               SASL_CONTINUE on success */
	if (result != SASL_CONTINUE && result != SASL_OK) 
	{
		if (NSDebugEnabled) NSLog(@"sasl_client_start failed (result = %d)", result);
		return NO;
	}
	
	if (outlen > 0) 
	{
		result = sasl_encode64(out, outlen, out64, sizeof out64, NULL);
		if (!result) 
		{
		    if (NSDebugEnabled) NSLog(@"AUTH %s %s\r\n", mechusing, out64);
			[stream writeFormat:@"AUTH %s %s\r\n", mechusing, out64];
		}
	} 
	else 
	{
		if (NSDebugEnabled) NSLog(@"AUTH %s\r\n", mechusing);
		[stream writeFormat:@"AUTH %s\r\n", mechusing];
	}
	
	while (result == SASL_OK || result == SASL_CONTINUE) 
	{
		NSString *response = [[self readResponse] objectAtIndex:0];
		
		if (NSDebugEnabled) NSLog(@"response = '%@'", response);
		
		if ([response hasPrefix:@"5"]) 
		{
			if (NSDebugEnabled) NSLog(@"Authentication failure");
			return NO;
		}
		
		if ([response hasPrefix:@"235"]) 
		{
			return YES;
		}
		NSAssert([response hasPrefix:@"3"], @"should have 3 as prefix");
		if (NSDebugEnabled) NSLog(@"Another step in the authentication process is necessary.");
		
		char in[4096];
		unsigned int inlen;
		const char *buf = [[response substringFromIndex:4] UTF8String];
		
		char newbuf[1024];
		
		strcpy(newbuf, buf);
				
		result = sasl_decode64(newbuf, strlen(newbuf), in, 4096, &inlen);
		if (result != SASL_OK) break;

		puts(in);
		
		do 
		{
			client_interact = NULL;
			out = NULL;
			outlen = 0;
			
			result = sasl_client_step(conn,  /* our context */
			in,    /* the data from the server */
			inlen, /* it's length */
			&client_interact,  /* this should be
			unallocated and NULL */
			&out,     /* filled in on success */
			&outlen); /* filled in on success */
			
			if (result == SASL_INTERACT)
			{
				[self fillin_interactions:client_interact];
			}
		} 
		
		while (result==SASL_INTERACT);
		
		if (result == SASL_OK || result == SASL_CONTINUE) 
		{
			result = sasl_encode64(out, outlen, out64, sizeof out64, NULL);
		}
		
		if (result == SASL_OK) 
		{
			if (NSDebugEnabled) NSLog(@"%s\r\n", out64);
			[stream writeFormat:@"%s\r\n", out64];
		}
	}
	
	// failed:
	return NO;
	
	/* old version without cyrus SASL lib only supporting PLAIN
	NSString *method;
    NSString *aUsername, *aPassword;
    NSEnumerator *methods = [authMethods reverseObjectEnumerator];
    
    aUsername = [self username];
    aPassword = [self password];
    
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
	 */
}

/*
// PLAIN authentication only
- (BOOL)__authPlainWithUsername:(NSString *)aUsername andPassword:(NSString *)aPassword
{        
    NSData *sesame;
    NSString *authString;
    
    NSParameterAssert(aUsername && aPassword);
    
    // initiate auth        
    sesame = [[[NSString stringWithFormat:@"\0%@\0%@", aUsername, aPassword] dataUsingEncoding: NSUTF8StringEncoding] encodeBase64];
    
    authString = [NSString stringWithFormat:@"AUTH PLAIN %@", [NSString stringWithCString: [sesame bytes] length: [sesame length]]];
    
    //OPDebugLog1(SMTPDEBUG, OPALL, @"auth string = (%@)", authString);
    [stream writeString: authString];
    
    [pendingResponses addObject:@"235"];
    
    [self assertServerAcceptedCommand];
    
    return YES;
}
*/
@end
