//
//  GIPOPJob.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 09.06.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "GIPOPJob.h"
#import "OPPOP3Session.h"
#import "OPJobs.h"
#import "G3Account.h"
#import "NSHost+GIReachability.h"
#import <OPNetwork/OPNetwork.h>
#import "NSApplication+OPExtensions.h"
#import "OPMBoxFile.h"
#import "NSData+MessageUtils.h"

@implementation GIPOPJob

// Socket timeout (60 secs)
#define TIMEOUT 60

- (void)retrieveMessagesFromPOPAccountJob:(NSDictionary *)arguments
/*" Retrieves using delegate for providing password. "*/
{
    G3Account *theAccount = [[account retain] autorelease];
    NSParameterAssert([theAccount isPOPAccount]);
    
    // finding host:
    [OPJobs setProgressInfo:[OPJobs indeterminateProgressInfoWithDescription:[NSString stringWithFormat:NSLocalizedString(@"finding %@", @"progress description in POP job"), [theAccount incomingServerName]]]];
    
    NSHost *host = [NSHost hostWithName:[theAccount incomingServerName]];
    [host name]; // I remember that was important, but I can't remember why
    
    if ([host isReachableWithNoStringsAttached])
    {
        // connecting to host:
        [OPJobs setProgressInfo:[OPJobs indeterminateProgressInfoWithDescription:[NSString stringWithFormat:NSLocalizedString(@"connecting to %@:%d", @"progress description in POP job"), [theAccount incomingServerName], [theAccount incomingServerPort]]]];
        
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
                [OPJobs setProgressInfo:[OPJobs indeterminateProgressInfoWithDescription:[NSString stringWithFormat:NSLocalizedString(@"opening secure connection to %@", @"progress description in POP job"), [theAccount incomingServerName]]]];
                
                [(OPSSLSocket*)[stream fileHandle] setAllowsAnyRootCertificate:[theAccount allowAnyRootSSLCertificate]];
                
                [stream negotiateEncryption];
            }
            
            // logging into POP server:
            [OPJobs setProgressInfo:[OPJobs indeterminateProgressInfoWithDescription:[NSString stringWithFormat:NSLocalizedString(@"logging in to %@", @"progress description in POP job"), [theAccount incomingServerName]]]];
            
            OPPOP3Session *pop3session = [[[OPPOP3Session alloc] initWithStream:stream andDelegate:self] autorelease];
            [pop3session setAutosaveName:[theAccount incomingServerName]];
            [pop3session openSession]; // also sets current postion cursor for maildrop
            
            // creating unique mbox file:
            NSString *mboxToImportDirectory = [[NSApp applicationSupportPath] stringByAppendingPathComponent:@"mboxes to import"];
            if (![[NSFileManager defaultManager] fileExistsAtPath:mboxToImportDirectory])
            {
                NSAssert1([[NSFileManager defaultManager] createDirectoryAtPath:mboxToImportDirectory attributes:nil], @"Could not create directory %@", mboxToImportDirectory);
            }
            
            NSString *pathTemplate = [mboxToImportDirectory stringByAppendingPathComponent:@"POP3Fetched-XXXXX"];
            
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
                
                while ((transferData = [pop3session nextTransferData]) && !shouldTerminate)
                {
                    [OPJobs setProgressInfo:[OPJobs progressInfoWithMinValue:0 maxValue:numberOfMessagesToFetch currentValue:fetchCount description:[NSString stringWithFormat:NSLocalizedString(@"fetching messages from %@", @"progress description in POP job"), [theAccount incomingServerName]]]];
                    
                    // putting onto disk:
                    [mboxFile appendMBoxData:[transferData mboxDataFromTransferDataWithEnvSender:nil]];
                    
                    fetchCount++;
                    shouldTerminate = [OPJobs shouldTerminate];
                }
                                                
                if (!shouldTerminate)
                {
                    // set result:
                    [OPJobs setResult:[mboxFile path]];
                    
                    // cleaning up maildrop:
                    [OPJobs setProgressInfo:[OPJobs indeterminateProgressInfoWithDescription:[NSString stringWithFormat:NSLocalizedString(@"cleaning up %@", @"progress description in POP job"), [theAccount incomingServerName]]]];
                    
                    [pop3session cleanUp];
                }
                else
                {
                    [[NSFileManager defaultManager] removeFileAtPath:[mboxFile path] handler:NULL];               
                }
            }
            @catch (NSException *localException)
            {
                [pop3session abortSession];
                [[NSFileManager defaultManager] removeFileAtPath:[mboxFile path] handler:NULL];               
                @throw;
            }
            @finally
            {
                [pool release];
            }
            
            [OPJobs setProgressInfo:[OPJobs indeterminateProgressInfoWithDescription:[NSString stringWithFormat:NSLocalizedString(@"loggin off from %@", @"progress description in POP job"), [theAccount incomingServerName]]]];
            
            [pop3session closeSession];
            
            if ([theAccount incomingServerType] == POP3S)
            {
                [OPJobs setProgressInfo:[OPJobs indeterminateProgressInfoWithDescription:[NSString stringWithFormat:NSLocalizedString(@"closing secure connection to %@", @"progress description in POP job"), [theAccount incomingServerName]]]];
                
                [stream shutdownEncryption];
            }
        }
        @catch (NSException *localException)
        {
            if ([[localException name] isEqualToString:OPPOP3AuthenticationFailedException])
            {
                // Authentication failed (assuming that the password was wrong) -> clearing password
                [theAccount setIncomingPassword:@""];
            }
            @throw;
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

- (id)initWithAccount:(G3Account *)anAccount
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

+ (void)retrieveMessagesFromPOPAccount:(G3Account *)anAccount
/*" Starts a background job for retrieving messages from the given POP account anAccount. One account can only be 'popped' by at most one pop job at a time. "*/
{
    NSParameterAssert([anAccount isPOPAccount]);
    
    NSMutableDictionary *jobArguments = [NSMutableDictionary dictionary];
    
    [jobArguments setObject:anAccount forKey:@"account"];
    
    [OPJobs scheduleJobWithName:[self jobName] target:[[[self alloc] initWithAccount:anAccount] autorelease] selector:@selector(retrieveMessagesFromPOPAccountJob:) arguments:jobArguments synchronizedObject:[anAccount incomingServerName]];
}

/******** POP3 delegate methods **********/

/*" required "*/
- (NSString *)usernameForPOP3Session:(OPPOP3Session *)aSession
{
    return [account incomingUsername];
}

- (NSString *)passwordForPOP3Session:(OPPOP3Session *)aSession
{
    NSString *password = [account incomingPassword];
    
    if (![password length])
    {
        password = [[[[OPJobs alloc] init] autorelease] runPasswordPanelWithAccount:account forIncomingPassword:YES];
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

- (NSDate *)deletionDate
/*"Calculates the date for mail deletion. Mails older than this date wil be deleted."*/
{
    int days = [account retrieveMessageInterval];
        
    if (days == 0) return [NSDate distantPast];
    if (days == -1) return [NSDate distantFuture];
    
    return [NSDate dateWithTimeIntervalSinceNow:days * -86400]; // 86400 = seconds per day
}

- (BOOL)shouldDeleteMessageWithMessageId:(NSString *)messageId date:(NSDate *)messageDate size:(long)size inPOP3Session:(OPPOP3Session *)aSession
{
    return [messageDate compare:[self deletionDate]] != NSOrderedDescending; /* date <= tooOldDate */
}

@end
