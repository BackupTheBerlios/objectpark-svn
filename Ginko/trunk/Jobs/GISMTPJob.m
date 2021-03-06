//
//  GISMTPJob.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 13.06.05.
//  Copyright 2005 Objectpark Group. All rights reserved.
//

#import "GISMTPJob.h"
#import "OPJob.h"
#import "GIAccount.h"
#import <OPDebug/OPLog.h>
#import <OPNetwork/OPNetwork.h>
#import "NSHost+GIReachability.h"
#import "OPPOP3Session.h"
#import "OPSMTP+InternetMessage.h"
#import "GIMessage.h"

@implementation GISMTPJob

#define POPTimeInterval (60 * 5)
#define TIMEOUT 60

- (void)authenticateViaPOP:(GIAccount *)anAccount
{
	OPJob *job = [OPJob job];
    [job setProgressInfo:[job indeterminateProgressInfoWithDescription:[NSString stringWithFormat:NSLocalizedString(@"authorization 'SMTP after POP' with %@", @"progress description in SMTP job"), [anAccount incomingServerName]]]];

    NSHost *host = [NSHost hostWithName:[anAccount incomingServerName]];
    [host name]; // I remember that was important, but I can't remember why
    NSAssert(host != nil, @"host should be created");
    
    if ([host isReachableWithNoStringsAttached]) 
    {
        // connecting to host:
        OPStream *stream = [OPStream streamConnectedToHost:host
                                                      port:[anAccount incomingServerPort]
                                               sendTimeout:TIMEOUT
                                            receiveTimeout:TIMEOUT];
        
        NSAssert2(stream != nil, @"could not connect to server %@:%d", [anAccount incomingServerName], [anAccount incomingServerPort]);
        
        @try 
        {
            // starting SSL if needed:
            if ([anAccount incomingServerType] == POP3S) 
            {
                [(OPSSLSocket *)[stream fileHandle] setAllowsAnyRootCertificate:[[anAccount valueForKey:@"allowAnyRootSSLCertificate"] boolValue]];
                
                [stream negotiateEncryption];
            }
                        
            OPPOP3Session *pop3session = [[[OPPOP3Session alloc] initWithStream:stream username:[anAccount valueForKey:@"incomingUsername"] andPassword:[anAccount incomingPassword]] autorelease];
            [pop3session openSession]; 
            [pop3session closeSession];

            if ([anAccount incomingServerType] == POP3S) 
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

- (void)sendMessagesViaSMTPAccountJob:(NSDictionary *)arguments
{
    GIAccount *theAccount = [[account retain] autorelease];
    NSArray *theMessages = [[messages retain] autorelease];
    NSMutableArray *sentMessages = [NSMutableArray array];
    OPJob *job = [OPJob job];
	
    // is theAccount an SMTP after POP account?
    if ([theAccount outgoingAuthenticationMethod] == SMTPAfterPOP) 
    {
        NSAssert([theAccount isPOPAccount], @"SMTP requires 'SMTP after POP' authentication but the given account is no POP account.");
        [self authenticateViaPOP:theAccount];
    }
    
    NSHost *host = [NSHost hostWithName:[theAccount outgoingServerName]];
    [host name];
    
    if ([host isReachableWithNoStringsAttached]) 
	{
        // connecting to host:
        [job setProgressInfo:[job indeterminateProgressInfoWithDescription:[NSString stringWithFormat:NSLocalizedString(@"connecting to %@:%d", @"progress description in SMTP job"), [theAccount outgoingServerName], [theAccount outgoingServerPort]]]];
        
        OPStream *stream = [OPStream streamConnectedToHost:host
                                                      port:[theAccount outgoingServerPort]
                                               sendTimeout:TIMEOUT
                                            receiveTimeout:TIMEOUT];
        
        NSAssert2(stream != nil, @"could not connect to server %@:%d", [theAccount outgoingServerName], [theAccount outgoingServerPort]);
        
        @try {
            // logging into SMTP server:
            [job setProgressInfo:[job indeterminateProgressInfoWithDescription:[NSString stringWithFormat:NSLocalizedString(@"logging in to %@", @"progress description in SMTP job"), [theAccount outgoingServerName]]]];
            
            OPSMTP *SMTP = [[[OPSMTP alloc] initWithStream:stream andDelegate:self] autorelease];
			
			[SMTP connect];
			
            NSEnumerator *enumerator = [theMessages objectEnumerator];
            
            // sending messages:
            NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
            @try 
			{
                GIMessage *message;
                
                while (message = [enumerator nextObject]) 
				{
                    [job setProgressInfo:[job indeterminateProgressInfoWithDescription:[NSString stringWithFormat: NSLocalizedString(@"sending message '%@'", @"progress description in SMTP job"), [message valueForKey:@"subject"]]]];
                    
                    @try 
					{
                        [SMTP sendMessage:[message internetMessage]];
                        [sentMessages addObject:message];
						
						// Make woosh-sound for each message sent:
						NSSound *woosh = [NSSound soundNamed:@"Mail Sent"];
						//while ([woosh isPlaying]) [NSThread sleepUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.5]]; // Make sure we hear one woosh per mail
						[woosh stop];
						[woosh play];
                    } 
					@catch (id localException) 
					{
                        NSLog(@"Error sending message %@: %@", [message valueForKey: @"subject"], [localException reason]);
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
                [job setProgressInfo:[job indeterminateProgressInfoWithDescription:[NSString stringWithFormat:NSLocalizedString(@"logging off from %@", @"progress description in SMTP job"), [theAccount incomingServerName]]]];
                [SMTP quit];
            }
			[pool release];
        } 
		@catch (id localException) 
		{
#warning We might have a wrong password, i.e. an auth failure. We should make sure, the respective dialog is displayed instead of failing silently!
            @throw;
        } 
		@finally 
		{
            [job setResult:[NSDictionary dictionaryWithObjectsAndKeys:
                sentMessages, @"sentMessages",
                theMessages, @"messages",
                nil, nil]];
        }
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

+ (NSString *)jobName
{
    return @"SMTP send";
}

+ (void)sendMessages:(NSArray *)someMessages viaSMTPAccount:(GIAccount *)anAccount
/*" Starts a background job for sending messages someMessages via the given SMTP account anAccount. One account can only be 'smtp'ed by at most one smtp job at a time. "*/
{
    NSParameterAssert([someMessages count]);
    NSParameterAssert(anAccount != nil);
	
	if ([[OPJob runningJobsWithSynchronizedObject:[anAccount outgoingServerName]] count] == 0)
	{
		NSMutableDictionary *jobArguments = [NSMutableDictionary dictionary];
		
		[OPJob scheduleJobWithName:[self jobName] target:[[[self alloc] initWithMessages:someMessages andAccount:anAccount] autorelease] selector:@selector(sendMessagesViaSMTPAccountJob:) argument:jobArguments synchronizedObject:[anAccount outgoingServerName]];
	}
}

@end

@implementation GISMTPJob (SMTPDelegate)

/*" required "*/
- (NSString *)usernameForSMTP:(OPSMTP *)aSMTP
{
    if ([account outgoingAuthenticationMethod] == SMTPAuthentication) 
	{
        return [account valueForKey:@"outgoingUsername"];
    }
    else return nil;
}

- (NSString *)passwordForSMTP:(OPSMTP *)aSMTP
{
    if ([account outgoingAuthenticationMethod] == SMTPAuthentication) 
	{
        NSString *password = [account outgoingPassword];
		if (![password length]) 
		{
			password = [[[[OPJob alloc] init] autorelease] runPasswordPanelWithAccount:account forIncomingPassword:NO];
		}
		return password;
    }
    else return nil;
}

- (NSString *)serverHostnameForSMTP:(OPSMTP *)aSMTP
{
	return [account outgoingServerName];
}

/*" optional "*/
- (BOOL)useSMTPS:(OPSMTP *)aSMTP
/*"OPTIONAL.
    Determines if SMTPS should be used instead of SMTP. Default is NO."*/
{
    return [account outgoingServerType] == SMTPS;
}

- (BOOL)allowAnyRootCertificateForSMTP:(OPSMTP *)aSMTP
/*"OPTIONAL.
    Determines if the root certificate should not be verified (YES) or not (NO).
    If the server uses a self signed certificate and you didn't install the corresponding root certificate
    you need to return YES to have the SSL handshake succeed. Default is NO."*/
{
    return [[account valueForKey:@"allowAnyRootSSLCertificate"] boolValue];
}

- (BOOL)allowExpiredCertificatesForSMTP:(OPSMTP *)aSMTP
/*"OPTIONAL.
    Determines if the SSL handshake should succeed (YES) if the server's certificate has expired, or not (NO).
    Default is NO."*/
{
    return [[account valueForKey:@"allowExpiredSSLCertificates"] boolValue];
}

@end
