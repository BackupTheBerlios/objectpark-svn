//
//  GISMTPOperation.m
//  Gina
//
//  Created by Axel Katerbau on 28.03.08.
//  Copyright 2008 Objectpark Group. All rights reserved.
//

#import "GISMTPOperation.h"
#import "OPSMTP.h"
#import "OPSMTP+InternetMessage.h"
#import "GIAccount.h"
#import "NSHost+GIReachability.h"
#import "OPPOP3Session.h"
#import <OPNetwork/OPNetwork.h>
#import "GIMessage.h"
#import "GIMailAddressTokenFieldDelegate.h"
#import <Foundation/NSDebug.h>

NSString *GISMTPOperationDidEndNotification = @"GISMTPOperationDidEndNotification";

@implementation GISMTPOperation

@synthesize account;
@synthesize messages;

/*" Starts a background job for sending messages someMessages via the given SMTP account anAccount. One account can only be 'smtp'ed by at most one smtp operation at a time. "*/
+ (void)sendMessages:(NSArray *)someMessages viaSMTPAccount:(GIAccount *)anAccount usingOperationQueue:(NSOperationQueue *)queue
{
	NSParameterAssert(someMessages.count);
    NSParameterAssert(anAccount != nil); // maybe check if anAccount has sufficient SMTP configuration
	
	@synchronized(queue)
	{
		for (NSOperation *operation in queue.operations)
		{
			if ([operation isKindOfClass:self])
			{
				if ([(GISMTPOperation *)operation account] == anAccount)
				{
					NSLog(@"GISMTPOperation: conflicting operation %@. New operation will not be set up.", operation);
					return;
				}
			}
		}
		
		id newOperation = [[[self alloc] initWithMessages:someMessages andAccount:anAccount] autorelease];
		NSAssert(newOperation != nil, @"operation couldn't be established");
		[queue addOperation:newOperation];
	}
}

- (id)initWithMessages:(NSArray *)someMessages andAccount:(GIAccount *)anAccount
{
	self = [super init];
    
	messages = [someMessages retain];
    account = [anAccount retain];
    
    return self;	
}

- (void)dealloc
{
	[messages release];
    [account release];
    [super dealloc];
}

#define POPTimeInterval (60 * 5)
#define TIMEOUT 60

- (void)authenticateViaPOP
{
    [self setIndeterminateProgressInfoWithDescription:[NSString stringWithFormat:NSLocalizedString(@"authorization 'SMTP after POP' with %@", @"progress description in SMTP job"), self.account.incomingServerName]];
	
    NSHost *host = [NSHost hostWithName:self.account.incomingServerName];
    [host name]; // I remember that was important, but I can't remember why
    NSAssert(host != nil, @"host should be created");
    
    if ([host isReachableWithNoStringsAttached]) 
    {
        // connecting to host:
        OPStream *stream = [OPStream streamConnectedToHost:host
                                                      port:self.account.incomingServerPort
                                               sendTimeout:TIMEOUT
                                            receiveTimeout:TIMEOUT];
        
        NSAssert2(stream != nil, @"could not connect to server %@:%d", self.account.incomingServerName, self.account.incomingServerPort);
        
        @try 
        {
            // starting SSL if needed:
            if (self.account.incomingServerType == POP3S) 
            {
                [(OPSSLSocket *)[stream fileHandle] setAllowsAnyRootCertificate:self.account.allowAnyRootSSLCertificate];
                
                [stream negotiateEncryption];
            }
			
            OPPOP3Session *pop3session = [[[OPPOP3Session alloc] initWithStream:stream username:self.account.incomingUsername andPassword:self.account.incomingPassword] autorelease];
            [pop3session openSession]; 
            [pop3session closeSession];
			
            if (self.account.incomingServerType == POP3S) 
            {                
                [stream shutdownEncryption];
            }
        } 
        @catch (id localException) 
        {
            NSLog(@"Exception while authentication via SMTP after POP <%@>", [localException reason]);
        } 
        @finally 
        {
            [stream close];
        }
    }
}

- (void)main
{
    NSMutableArray *sentMessages = [NSMutableArray array];
	
    // is theAccount an SMTP after POP account?
    if (self.account.outgoingAuthenticationMethod == SMTPAfterPOP) 
    {
        NSAssert(account.isPOPAccount, @"SMTP requires 'SMTP after POP' authentication but the given account is no POP account.");
        [self authenticateViaPOP];
    }
    
    NSHost *host = [NSHost hostWithName:self.account.outgoingServerName];
    [host name];
    
    if ([host isReachableWithNoStringsAttached]) 
	{
        @try 
		{
			// connecting to host:
			[self setIndeterminateProgressInfoWithDescription:[NSString stringWithFormat:NSLocalizedString(@"connecting to %@:%d", @"progress description in SMTP job"), self.account.outgoingServerName, self.account.outgoingServerPort]];
			
			OPStream *stream = [OPStream streamConnectedToHost:host
														  port:self.account.outgoingServerPort
												   sendTimeout:TIMEOUT
												receiveTimeout:TIMEOUT];
			
			NSAssert2(stream != nil, @"Could not connect to SMTP server %@:%d.", self.account.outgoingServerName, self.account.outgoingServerPort);
			
            // logging into SMTP server:
			[self setIndeterminateProgressInfoWithDescription:[NSString stringWithFormat:NSLocalizedString(@"logging in to %@", @"progress description in SMTP job"), self.account.outgoingServerName]];
            
            OPSMTP *SMTP = [[[OPSMTP alloc] initWithStream:stream andDelegate:self] autorelease];
			
			[SMTP connect];
			
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSMTPServerDoesNotLikeRecipient:) name:OPSMTPServerDoesNotLikeRecipientNotification object:SMTP];
			
            // sending messages:
            NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
            @try 
			{
				for (GIMessage *message in self.messages)
				{
					[self setIndeterminateProgressInfoWithDescription:[NSString stringWithFormat: NSLocalizedString(@"sending message '%@'", @"progress description in SMTP job"), message.subject]];
                    
                    @try 
					{
                        [SMTP sendMessage:message.internetMessage];
						
                        [sentMessages addObject:message];
						
						// Make woosh-sound for each message sent:
						NSSound *woosh = [NSSound soundNamed:@"Mail Sent"];
						//while ([woosh isPlaying]) [NSThread sleepUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.5]]; // Make sure we hear one woosh per mail
						[woosh stop];
						[woosh play];
                    } 
					@catch (id localException) 
					{
                        NSLog(@"Error sending message %@: %@", message.subject, [localException reason]);
                    }
                    [pool release]; pool = [[NSAutoreleasePool alloc] init];
                }
            } 
			@catch (id localException) 
			{
                @throw;
            } 
			@finally 
			{
				[self setIndeterminateProgressInfoWithDescription:[NSString stringWithFormat:NSLocalizedString(@"logging off from %@", @"progress description in SMTP job"), self.account.incomingServerName]];
                [SMTP quit];
            }
			[pool release];
        } 
		@catch (id localException) 
		{
			if ([[localException name] isEqualToString:OPSMTPAuthenticationFailedException])
			{
				[self performSelectorOnMainThread:@selector(runAuthenticationErrorDialog:) withObject:[localException reason] waitUntilDone:YES];
				
				if (authenticationErrorDialogResult != NSAlertFirstButtonReturn)
				{
					if (NSDebugEnabled) NSLog(@"Authentication failed (assuming that the password was wrong) -> clearing password");
					// Authentication failed (assuming that the password was wrong) -> clearing password
					self.account.outgoingPassword = @"";
				}
			}
			else 
			{
				[[self class] presentException:localException];
			}
        } 
		@finally 
		{
			[[NSNotificationCenter defaultCenter] removeObserver:self];
			
			NSNotification *notification = [NSNotification notificationWithName:GISMTPOperationDidEndNotification object:self.account userInfo:[NSDictionary dictionaryWithObjectsAndKeys:sentMessages, @"sentMessages", self.messages, @"messages", nil, nil]];
			
			[[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:NO];
        }
    }
	
	[self setIndeterminateProgressInfoWithDescription:@""];
}

- (void)runAuthenticationErrorDialog:(NSString *)errorMessage
{
	NSAlert *alert = [[NSAlert alloc] init];
	
	[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Authentication error with SMTP server '%@'.\nTry with new password next time?", @"AuthenticationErrorDialog"), self.account.outgoingServerName]];
	[alert setInformativeText:errorMessage];
	
	[alert addButtonWithTitle:NSLocalizedString(@"Keep Password", @"AuthenticationErrorDialog")];
	[alert addButtonWithTitle:NSLocalizedString(@"Try with new Password next Time", @"AuthenticationErrorDialog")];
	
	authenticationErrorDialogResult = [alert runModal];
	
	[alert release];
}

- (void)removeRecipientFromLRUCache:(NSString *)recipient
{
	NSParameterAssert([NSThread currentThread] == [NSThread mainThread]);
	[GIMailAddressTokenFieldDelegate removeFromLRUMailAddresses:recipient];
}

- (void)handleSMTPServerDoesNotLikeRecipient:(NSNotification *)aNotification
{
	NSString *recipient = [[aNotification userInfo] objectForKey:@"Recipient"];
	NSAssert (recipient != nil, @"nil recipient not expected");
	
	[self performSelectorOnMainThread:@selector(removeRecipientFromLRUCache:) withObject:recipient waitUntilDone:YES];
}

@end

@implementation GISMTPOperation (SMTPDelegate)

/*" required "*/
- (NSString *)usernameForSMTP:(OPSMTP *)aSMTP
{
    if (account.outgoingAuthenticationMethod == SMTPAuthentication) 
	{
        return account.outgoingUsername;
    }
    else return nil;
}

- (NSString *)passwordForSMTP:(OPSMTP *)aSMTP
{
    if (account.outgoingAuthenticationMethod == SMTPAuthentication) 
	{
        NSString *password = account.outgoingPassword;
		if (!password.length) 
		{
			password = [GIOperation runPasswordPanelWithAccount:account forIncomingPassword:NO];
		}
		return password;
    }
    else return nil;
}

- (NSString *)serverHostnameForSMTP:(OPSMTP *)aSMTP
{
	return account.outgoingServerName;
}

/*" optional "*/
- (BOOL)useSMTPS:(OPSMTP *)aSMTP
/*"OPTIONAL.
 Determines if SMTPS should be used instead of SMTP. Default is NO."*/
{
    return account.outgoingServerType == SMTPS;
}

- (BOOL)allowAnyRootCertificateForSMTP:(OPSMTP *)aSMTP
/*"OPTIONAL.
 Determines if the root certificate should not be verified (YES) or not (NO).
 If the server uses a self signed certificate and you didn't install the corresponding root certificate
 you need to return YES to have the SSL handshake succeed. Default is NO."*/
{
    return account.allowAnyRootSSLCertificate;
}

- (BOOL)allowExpiredCertificatesForSMTP:(OPSMTP *)aSMTP
/*"OPTIONAL.
 Determines if the SSL handshake should succeed (YES) if the server's certificate has expired, or not (NO).
 Default is NO."*/
{
    return account.allowExpiredSSLCertificates;
}

@end
