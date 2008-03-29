//
//  GIPOPOperation.m
//  Gina
//
//  Created by Axel Katerbau on 16.03.08.
//  Copyright 2008 Objectpark Group. All rights reserved.
//

#import "GIPOPOperation.h"
#import "GIAccount.h"
#import "NSHost+GIReachability.h"
#import <OPNetwork/OPNetwork.h>
#import <InternetMessage/OPPOP3Session.h>
#import <InternetMessage/NSApplication+OPExtensions.h>
#import <InternetMessage/NSData+MessageUtils.h>
#import <Foundation/NSDebug.h>

NSString *GIPOPOperationDidStartNotification = @"GIPOPOperationDidStartNotification";
NSString *GIPOPOperationDidEndNotification = @"GIPOPOperationDidEndNotification";

@implementation GIPOPOperation

@synthesize account;

/*" Starts a background job for retrieving messages from the given POP account anAccount. One account can only be 'popped' by at most one pop job at a time. "*/
+ (void)retrieveMessagesFromPOPAccount:(GIAccount *)anAccount usingOperationQueue:(NSOperationQueue *)queue
{
    NSParameterAssert([anAccount isPOPAccount]);
	
	for (NSOperation *operation in queue.operations)
	{
		if ([operation isKindOfClass:self])
		{
			if ([(GIPOPOperation *)operation account] == anAccount)
			{
				NSLog(@"GIPOPOperation: conflicting operation %@. New operation will not be set up.", operation);
				return;
			}
		}
	}
	
	id newOperation = [[[self alloc] initWithAccount:anAccount] autorelease];
	[queue addOperation:newOperation];
}

- (NSDate *)deletionDate
/*" Calculates the date for mail deletion. Mails older than this date wil be deleted. "*/
{
    int days = self.account.leaveOnServerDuration;
	
    if (days == -1) return [NSDate distantPast];
    if (days == 0) return [NSDate distantFuture];
    
    return [NSDate dateWithTimeIntervalSinceNow:days * -86400]; // 86400 = seconds per day
}

- (void)cancel
{
	[super cancel];
}

// Socket timeout (60 secs)
#define TIMEOUT 60

/*" Retrieves using delegate for providing password. "*/
- (void)main
{
	@try
	{
		BOOL sentStartedNotification = NO;

		// finding host:
		[self setIndeterminateProgressInfoWithDescription:[NSString stringWithFormat:NSLocalizedString(@"finding %@", @"progress description in POP job"), self.account.incomingServerName]];
		
		NSHost *host = [NSHost hostWithName:self.account.incomingServerName];
		[host name]; // I remember that was important, but I can't remember why
		
		if ([host isReachableWithNoStringsAttached])
		{
			// connecting to host:
			[self setIndeterminateProgressInfoWithDescription:[NSString stringWithFormat:NSLocalizedString(@"connecting to %@:%d", @"progress description in POP job"), self.account.incomingServerName, self.account.incomingServerPort]];
			
			OPStream *stream = [OPStream streamConnectedToHost:host
														  port:self.account.incomingServerPort
												   sendTimeout:TIMEOUT
												receiveTimeout:TIMEOUT];
			
			NSAssert2(stream != nil, @"No connection to server %@:%d", self.account.incomingServerName, self.account.incomingServerPort);
			
			@try
			{
				// starting SSL if needed:
				if (self.account.incomingServerType == POP3S)
				{
					[self setIndeterminateProgressInfoWithDescription:[NSString stringWithFormat:NSLocalizedString(@"opening secure connection to %@", @"progress description in POP job"), self.account.incomingServerName]];
					
					[(OPSSLSocket*)[stream fileHandle] setAllowsAnyRootCertificate:self.account.allowAnyRootSSLCertificate];
					
					[stream negotiateEncryption];
				}
				
				// logging into POP server:
				[self setIndeterminateProgressInfoWithDescription:[NSString stringWithFormat:NSLocalizedString(@"logging in to %@", @"progress description in POP job"), self.account.incomingServerName]];
				
				OPPOP3Session *pop3session = [[[OPPOP3Session alloc] initWithStream:stream andDelegate:self] autorelease];
				[pop3session setAutosaveName:self.account.incomingServerName];
				[pop3session openSession]; // also sets current postion cursor for maildrop
				
				// creating unique mbox file:
				NSString *importPath = [[NSApp applicationSupportPath] stringByAppendingPathComponent:@"TransferData to import"];
				if (![[NSFileManager defaultManager] fileExistsAtPath:importPath])
				{
					NSAssert1([[NSFileManager defaultManager] createDirectoryAtPath:importPath attributes: nil], @"Could not create directory %@", importPath);
				}
				
				NSString *dateString = [[NSCalendarDate date] descriptionWithCalendarFormat:@"%d%m%y%H%M%S"];
				
				// fetching messages:
				NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
				@try
				{
					int numberOfMessagesToFetch = ([pop3session maildropSize] - [pop3session currentPosition]) + 1;
					int fetchCount = 0;
					NSData *transferData = nil;
					unsigned long runningNo = 0;
					
					while ((transferData = [pop3session nextTransferData]) && !self.isCancelled) 
					{
						[self setProgressInfoWithMinValue:0 maxValue:numberOfMessagesToFetch currentValue:fetchCount description:[NSString stringWithFormat:NSLocalizedString(@"getting message #%u/%u from server %@", @"progress description in POP job"), fetchCount, numberOfMessagesToFetch, self.account.incomingServerName]];
						
						// putting onto disk:
						NSString *transferDataPath = [importPath stringByAppendingPathComponent:[NSString stringWithFormat:@"Msg-%@-%@-%lu.gml", self.account.incomingServerName, dateString, runningNo++]];
						
						if (![transferData writeToFile:transferDataPath atomically:YES])
						{
							@throw [NSException exceptionWithName:NSGenericException reason:@"Transfer data couldn't be written." userInfo:nil];
						}
									
						if (!sentStartedNotification)
						{
							NSNotification *notification = [NSNotification notificationWithName:GIPOPOperationDidStartNotification object:self.account];
							
							[[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:NO];

							sentStartedNotification = YES;
						}
						
						fetchCount++;
					}
										
					// cleaning up maildrop:
					if (![[self deletionDate] isEqualTo:[NSDate distantFuture]]) 
					{
						[self setIndeterminateProgressInfoWithDescription:[NSString stringWithFormat:NSLocalizedString(@"cleaning up %@", @"progress description in POP job"), self.account.incomingServerName]];
						
						[pop3session cleanUp];
					}
				} 
				@catch (id localException) 
				{
					[pop3session abortSession];
					//                [[NSFileManager defaultManager] removeFileAtPath:[mboxFile path] handler:NULL];     
					@throw;
				} 
				[pool release]; pool = nil;
				
				[self setIndeterminateProgressInfoWithDescription:[NSString stringWithFormat:NSLocalizedString(@"logging off from %@", @"progress description in POP job"), self.account.incomingServerName]];
				
				[pop3session closeSession];
				
				if (self.account.incomingServerType == POP3S)
				{
					[self setIndeterminateProgressInfoWithDescription:[NSString stringWithFormat:NSLocalizedString(@"closing secure connection to %@", @"progress description in POP job"), self.account.incomingServerName]];
					
					[stream shutdownEncryption];
				}
			}
			@catch (id localException)
			{
				if ([[localException name] isEqualToString:OPPOP3AuthenticationFailedException])
				{
					[self performSelectorOnMainThread:@selector(runAuthenticationErrorDialog:) withObject:[localException reason] waitUntilDone:YES];
					
					if (authenticationErrorDialogResult != NSAlertFirstButtonReturn)
					{
						if (NSDebugEnabled) NSLog(@"Authentication failed (assuming that the password was wrong) -> clearing password");
						// Authentication failed (assuming that the password was wrong) -> clearing password
						self.account.incomingPassword = @"";
					}
				}
				else @throw;
			}
			@finally
			{
				[stream close];
				
				if (sentStartedNotification)
				{
					NSNotification *notification = [NSNotification notificationWithName:GIPOPOperationDidEndNotification object:self.account];
					
					[[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:NO];
				}
			}
		} 
		else 
		{
			NSLog(@"Host %@ not reachable. Skipping retrieval.\n", self.account.incomingServerName);
		}
	}
	@catch (NSException *localException)
	{
		[[self class] presentException:localException];
	}
#warning Remove additional posting of GIPOPOperationDidEndNotification?
	[[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:[NSNotification notificationWithName:GIPOPOperationDidEndNotification object:self.account] waitUntilDone:NO]; // just for testing!!

}

- (id)initWithAccount:(GIAccount *)anAccount
{
    self = [super init];
    
    account = [anAccount retain];
    
    return self;
}

- (void)dealloc
{
    [account release];
    [super dealloc];
}

- (void)runAuthenticationErrorDialog:(NSString *)errorMessage
{
	NSAlert *alert = [[NSAlert alloc] init];
	
	[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Authentication error with POP server '%@'.\nTry with new password next time?", @"AuthenticationErrorDialog"), [account incomingServerName]]];
	[alert setInformativeText:errorMessage];
	
	[alert addButtonWithTitle:NSLocalizedString(@"Keep Password", @"AuthenticationErrorDialog")];
	[alert addButtonWithTitle:NSLocalizedString(@"Try with new Password next Time", @"AuthenticationErrorDialog")];
	
	authenticationErrorDialogResult = [alert runModal];
	
	[alert release];
}

/******** POP3 delegate methods **********/

/*" required "*/
- (NSString *)usernameForPOP3Session:(OPPOP3Session *)aSession
{
    return self.account.incomingUsername;
}

- (NSString *)passwordForPOP3Session:(OPPOP3Session *)aSession
{
    NSString *password = self.account.incomingPassword;
    
    if (![password length]) 
	{
        password = [GIOperation runPasswordPanelWithAccount:account forIncomingPassword:YES];
    }
    return password;
}

/*" optional "*/
- (BOOL)APOPRequiredForPOP3Session:(OPPOP3Session *)aSession
{
    return (self.account.incomingAuthenticationMethod == APOPRequired);
}

#ifdef _0
- (BOOL)shouldTryAuthenticationMethod:(NSString *)authenticationMethod inPOP3Session:(OPPOP3Session *)aSession
/*" Optional. Returns whether the given POP3Session aSession should try the authentication type given
 in authenticationMethod. If not implemented at least plain text authentication is tried. "*/
{
    if (([[account objectForKey:OPAPOPPreventAPOP] intValue]) && ([authenticationMethod isEqualToString:OPPOP3APOPAuthenticationMethod]))
    {
        return NO;
    }
    return YES;
}

- (void)authenticationMethod:(NSString *)authenticationMethod succeededInPOP3Session:(OPPOP3Session *)aSession
/*" Optional. Informs the receiver about what authentication type succeeded. "*/
{
}
*/
#endif

- (BOOL)shouldContinueWithOtherAuthenticationMethodAfterFailedAuthentication:(NSString *)authenticationMethod inPOP3Session:(OPPOP3Session *)aSession
/*" Optional. Asks whether other authentication methods should be tried as the given authenticationMethod failed. "*/
{
    return YES;
}

- (BOOL)shouldDeleteMessageWithMessageId:(NSString *)messageId date:(NSDate *)messageDate size:(long)size inPOP3Session:(OPPOP3Session *)aSession
{
	//NSLog(@"cleanup: %@", messageId);
    return [messageDate compare:[self deletionDate]] != NSOrderedDescending; /* date <= tooOldDate */
}

@end
