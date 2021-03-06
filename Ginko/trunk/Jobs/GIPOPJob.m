//
//  GIPOPJob.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 09.06.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "GIPOPJob.h"
#import "OPPOP3Session.h"
#import "OPJob.h"
#import "GIAccount.h"
#import "NSHost+GIReachability.h"
#import <OPNetwork/OPNetwork.h>
#import "NSApplication+OPExtensions.h"
#import "OPMBoxFile.h"
#import "NSData+MessageUtils.h"

@implementation GIPOPJob

// Socket timeout (60 secs)
#define TIMEOUT 60

- (NSDate *)deletionDate
/*" Calculates the date for mail deletion. Mails older than this date wil be deleted. "*/
{
    int days = [account leaveOnServerDuration];
	
    if (days == -1) return [NSDate distantPast];
    if (days == 0) return [NSDate distantFuture];
    
    return [NSDate dateWithTimeIntervalSinceNow:days * -86400]; // 86400 = seconds per day
}

- (void)runAuthenticationErrorDialog:(NSString *)errorMessage
{
	NSAlert *alert = [[NSAlert alloc] init];
	
	[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Authentication error with server '%@'.\nTry with new password next time?", @"AuthenticationErrorDialog"), [account incomingServerName]]];
	[alert setInformativeText:errorMessage];
	
	[alert addButtonWithTitle:NSLocalizedString(@"Keep Password", @"AuthenticationErrorDialog")];
	[alert addButtonWithTitle:NSLocalizedString(@"Try with new Password next Time", @"AuthenticationErrorDialog")];
	
	authenticationErrorDialogResult = [alert runModal];
	
	[alert release];
}

+ (NSString*) mboxesToImportDirectory
{
	NSString* mboxesToImportDirectory = [[NSApp applicationSupportPath] stringByAppendingPathComponent:@"mboxes to import"];
	return mboxesToImportDirectory;
}

- (void)retrieveMessagesFromPOPAccountJob:(NSDictionary *)arguments
/*" Retrieves using delegate for providing password. "*/
{
    GIAccount *theAccount = [[account retain] autorelease];
    NSParameterAssert([theAccount isPOPAccount]);
    
    // finding host:
	OPJob *job = [OPJob job];
    [job setProgressInfo:[job indeterminateProgressInfoWithDescription:[NSString stringWithFormat:NSLocalizedString(@"finding %@", @"progress description in POP job"), [theAccount incomingServerName]]]];
    
    NSHost *host = [NSHost hostWithName:[theAccount incomingServerName]];
    [host name]; // I remember that was important, but I can't remember why
    
    if ([host isReachableWithNoStringsAttached])
    {
        // connecting to host:
        [job setProgressInfo:[job indeterminateProgressInfoWithDescription:[NSString stringWithFormat:NSLocalizedString(@"connecting to %@:%d", @"progress description in POP job"), [theAccount incomingServerName], [theAccount incomingServerPort]]]];
        
        OPStream *stream = [OPStream streamConnectedToHost:host
                                                      port:[theAccount incomingServerPort]
                                               sendTimeout:TIMEOUT
                                            receiveTimeout:TIMEOUT];
        
        NSAssert2(stream != nil, @"could not connect to server %@:%d", [theAccount incomingServerName], [theAccount incomingServerPort]);
        
        @try
        {
            // starting SSL if needed:
            if ([theAccount incomingServerType] == POP3S)
            {
                [job setProgressInfo:[job indeterminateProgressInfoWithDescription:[NSString stringWithFormat:NSLocalizedString(@"opening secure connection to %@", @"progress description in POP job"), [theAccount incomingServerName]]]];
                
                [(OPSSLSocket*)[stream fileHandle] setAllowsAnyRootCertificate:[[theAccount valueForKey:@"allowAnyRootSSLCertificate"] boolValue]];
                
                [stream negotiateEncryption];
            }
            
            // logging into POP server:
            [job setProgressInfo:[job indeterminateProgressInfoWithDescription:[NSString stringWithFormat:NSLocalizedString(@"logging in to %@", @"progress description in POP job"), [theAccount incomingServerName]]]];
            
            OPPOP3Session *pop3session = [[[OPPOP3Session alloc] initWithStream:stream andDelegate:self] autorelease];
            [pop3session setAutosaveName:[theAccount incomingServerName]];
            [pop3session openSession]; // also sets current postion cursor for maildrop
            
            // creating unique mbox file:
            NSString *mboxToImportDirectory = [[NSApp applicationSupportPath] stringByAppendingPathComponent:@"mboxes to import"];
            if (![[NSFileManager defaultManager] fileExistsAtPath:mboxToImportDirectory])
            {
                NSAssert1([[NSFileManager defaultManager] createDirectoryAtPath:mboxToImportDirectory attributes: nil], @"Could not create directory %@", mboxToImportDirectory);
            }
            
            NSString *pathTemplate = [mboxToImportDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"POP3Fetched-%@-XX", [[NSCalendarDate date] descriptionWithCalendarFormat:@"%d%m%y%H%M%S"]]];
            
            OPMBoxFile *mboxFile = [OPMBoxFile createMboxFileWithPathTemplate:pathTemplate];
            NSAssert(mboxFile != nil, @"could not open unique mbox file");
            
            // fetching messages:
            NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
            @try
            {
                int numberOfMessagesToFetch = ([pop3session maildropSize] - [pop3session currentPosition]) + 1;
                int fetchCount = 0;
                BOOL shouldTerminate = NO;
                NSData *transferData = nil;
                
                while ((transferData = [pop3session nextTransferData]) && !shouldTerminate) {
                    [job setProgressInfo:[job progressInfoWithMinValue:0 maxValue:numberOfMessagesToFetch currentValue:fetchCount description:[NSString stringWithFormat:NSLocalizedString(@"getting message #%u/%u from server %@", @"progress description in POP job"), fetchCount, numberOfMessagesToFetch, [theAccount incomingServerName]]]];
                    
                    // putting onto disk:
                    [mboxFile appendMBoxData:[transferData mboxDataFromTransferDataWithEnvSender:nil]];
                    
                    fetchCount++;
                    shouldTerminate = [job shouldTerminate];
                }
                
                // set result:
				if (fetchCount > 0) {
					[job setResult:[mboxFile path]];
				} else {
					[mboxFile remove];
				}
                
                // cleaning up maildrop:
				if (![[self deletionDate] isEqualTo:[NSDate distantFuture]]) {
					[job setProgressInfo:[job indeterminateProgressInfoWithDescription:[NSString stringWithFormat:NSLocalizedString(@"cleaning up %@", @"progress description in POP job"), [theAccount incomingServerName]]]];
					
					[pop3session cleanUp];
				}
            } @catch (id localException) {
                [pop3session abortSession];
                [[NSFileManager defaultManager] removeFileAtPath: [mboxFile path] handler: NULL];     
                @throw;
            } 
			[pool release]; pool = nil;

            
            [job setProgressInfo: [job indeterminateProgressInfoWithDescription: [NSString stringWithFormat: NSLocalizedString(@"logging off from %@", @"progress description in POP job"), [theAccount incomingServerName]]]];
            
            [pop3session closeSession];
            
            if ([theAccount incomingServerType] == POP3S)
            {
                [job setProgressInfo:[job indeterminateProgressInfoWithDescription: [NSString stringWithFormat: NSLocalizedString(@"closing secure connection to %@", @"progress description in POP job"), [theAccount incomingServerName]]]];
                
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
					[theAccount setIncomingPassword:@""];
				}
            }
			else @throw;
        }
        @finally
        {
            [stream close];
        }
    } 
    else 
    {
        NSLog(@"Host %@ not reachable. Skipping retrieval.\n", [theAccount incomingServerName]);
    }
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

+ (NSString *)jobName
{
    return @"POP3 fetch";
}

+ (void)retrieveMessagesFromPOPAccount:(GIAccount *)anAccount
/*" Starts a background job for retrieving messages from the given POP account anAccount. One account can only be 'popped' by at most one pop job at a time. "*/
{
    NSParameterAssert([anAccount isPOPAccount]);
 
	NSArray *conflictingJobs = [OPJob runningJobsWithSynchronizedObject:[anAccount incomingServerName]];
	if ([conflictingJobs count] == 0)
	{
		NSMutableDictionary *jobArguments = [NSMutableDictionary dictionary];
		
		[jobArguments setObject:anAccount forKey:@"account"];
		
		[OPJob scheduleJobWithName:[self jobName] target:[[[self alloc] initWithAccount:anAccount] autorelease] selector:@selector(retrieveMessagesFromPOPAccountJob:) argument:jobArguments synchronizedObject:[anAccount incomingServerName]];
	}
	else
	{
		NSLog(@"POPJob: conflicting jobs %@", conflictingJobs);
	}
}

/******** POP3 delegate methods **********/

/*" required "*/
- (NSString *)usernameForPOP3Session:(OPPOP3Session *)aSession
{
    return [account valueForKey:@"incomingUsername"];
}

- (NSString *)passwordForPOP3Session:(OPPOP3Session *)aSession
{
    NSString *password = [account incomingPassword];
    
    if (![password length]) 
	{
        password = [[[[OPJob alloc] init] autorelease] runPasswordPanelWithAccount:account forIncomingPassword:YES];
    }
    return password;
}

/*" optional "*/
- (BOOL)APOPRequiredForPOP3Session:(OPPOP3Session *)aSession
{
    return ([account incomingAuthenticationMethod] == APOPRequired);
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
