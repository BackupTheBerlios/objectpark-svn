//
//  GIAccount.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 18.10.05.
//  Copyright 2005 The Objectpark Group. All rights reserved.
//

#import "GIAccount.h"
//#import "OPPersistentObject+Extensions.h"
#import <Security/Security.h>
#import <Foundation/NSDebug.h>
#import "NSString+Extensions.h"
//#import "GIPOPJob.h"
//#import "GISMTPJob.h"
//#import "GIApplication.h"
#import "GIProfile.h"
#import "GIMessage.h"
#import "OPPersistence.h"

@implementation GIAccount

@synthesize incomingUsername, outgoingUsername, outgoingServerName, incomingServerName;

+ (BOOL) cachesAllObjects
{
	return YES;
}

+ (int)defaultPortForIncomingServerType:(int)serverType
{
    switch (serverType) 
    {
        case POP3: return 110;
        case POP3S: return 995;
        case NNTP: return 119;
        case NNTPS: return 593;
        default: return -1;
    }
}

+ (int)defaultPortForOutgoingServerType:(int)serverType
{
    switch (serverType) 
    {
        case SMTP: return 25;
        case SMTPS: return 563;
        case SMTPTLS: return 25;
        default: return -1;
    }
}

- (id)init
/*" Designated initializer. "*/
{
	if (self = [super init]) {
		verifySSLCertificateChain = YES;
	}
	return self;
}


- (void) dealloc
{
	[name release];
	[incomingUsername release];
	[outgoingUsername release];
	[retrieveMessageInterval release];
	[outgoingServerName release];
	[incomingServerName release];
	[profiles release];

    [super dealloc];
}

- (int)incomingServerType 
{
	return incomingServerType;
}

- (void)setIncomingServerType:(int)value 
{
    [self willChangeValueForKey:@"incomingServerType"];

#warning Add dependency "incomingServerType" - "isPOPAccount"!
//    [self willChangeValueForKey:@"POPAccount"]; // signalling -isPOPAccount changed
//    [self didChangeValueForKey:@"POPAccount"];	

    // A change of the server type also has effect on the port. The Account is 'touched' to have bindings recognize the change.
    [self setIncomingServerPort:0];
    [self willChangeValueForKey:@"incomingServerDefaultPort"];
	incomingServerType = value;
    
    if (![self isPOPAccount]) {
        if ([self incomingAuthenticationMethod] != PlainText)
        {
            [self setIncomingAuthenticationMethod:PlainText];
        }
    }
	[self didChangeValueForKey:@"incomingServerDefaultPort"];
	[self didChangeValueForKey:@"incomingServerType"];


}


- (SecProtocolType)incomingSecProtocolType
{
    switch ([self incomingServerType])
    {
        case POP3:
            return kSecProtocolTypePOP3;
        case POP3S:
            return kSecProtocolTypePOP3S;
        case NNTP:
            return kSecProtocolTypeNNTP;
        case NNTPS:
            return kSecProtocolTypeNNTPS;
        default:
            return '    ';
    }    
}

- (NSString *)incomingPasswordItemRef:(SecKeychainItemRef *)itemRef
/*" Accesses keychain to get password. "*/
{
    NSAssert([self incomingServerName] > 0, @"server name not set");
    const char *serverName = [[self incomingServerName] UTF8String];
    NSAssert([self valueForKey:@"incomingUsername"] > 0, @"user name not set");
    const char *accountName = [[self valueForKey: @"incomingUsername"] UTF8String];
    UInt32 passwordLength;
    void *passwordData;
    NSString *result = nil;
    
    OSStatus err = SecKeychainFindInternetPassword(NULL, //<#CFTypeRef keychainOrArray#>
                                                   strlen(serverName), //<#UInt32 serverNameLength#>
                                                   serverName, //<#const char * serverName#>
                                                   0, //<#UInt32 securityDomainLength#>
                                                   NULL, //<#const char * securityDomain#>
                                                   strlen(accountName), //<#UInt32 accountNameLength#>
                                                   accountName, //<#const char * accountName#>
                                                   0, //<#UInt32 pathLength#>
                                                   NULL, //<#const char * path#>
                                                   (UInt16)[self incomingServerPort], //<#UInt16 port#>
                                                   [self incomingSecProtocolType], //<#SecProtocolType protocol#>
                                                   kSecAuthenticationTypeDefault, //<#SecAuthenticationType authenticationType#>
                                                   &passwordLength, //<#UInt32 * passwordLength#>
                                                   &passwordData, //<#void * * passwordData#>
                                                   itemRef); //<#SecKeychainItemRef * itemRef#>
    if (err != noErr) 
	{
        if (NSDebugEnabled) NSLog(@"Error with getting password (%d)", err);
    } 
	else 
	{
        NSData *data = [NSData dataWithBytes:passwordData length:passwordLength];
        result = [NSString stringWithData:data encoding:NSUTF8StringEncoding]; 
        
        err = SecKeychainItemFreeContent(NULL,           //No attribute data to release
                                         passwordData);    //Release data buffer allocated 
                                         
        if (err != noErr) 
		{
            if (NSDebugEnabled) NSLog(@"Error with getting password (%d)", err);
        }
    }
    
    return result;
}

- (NSString *)incomingPassword
{
    SecKeychainItemRef itemRef;
    NSString *result = [self incomingPasswordItemRef:&itemRef];
    return result;
}

- (void)setIncomingPassword:(NSString *)aPassword
/*" Uses keychain to store password. "*/
{
    const char *serverName = [[self incomingServerName] UTF8String];
    const char *accountName = [[self valueForKey: @"incomingUsername"] UTF8String];
    const char *password = [aPassword UTF8String];
    OSStatus err;
    SecKeychainItemRef itemRef = NULL;
    
    if ([self incomingPasswordItemRef:&itemRef])
    {        
        err = SecKeychainItemModifyAttributesAndData(
                                                     itemRef, // the item reference
                                                     NULL, // no change to attributes
                                                     strlen(password),  // length of password
                                                     password // pointer to password data
                                                     );
    } 
    else 
    {
        err = SecKeychainAddInternetPassword (
                                              NULL, // SecKeychainRef keychain,
                                              strlen(serverName), // UInt32 serverNameLength,
                                              serverName, //const char *serverName,
                                              0, // UInt32 securityDomainLength,
                                              NULL, // const char *securityDomain,
                                              strlen(accountName), // UInt32 accountNameLength,
                                              accountName, // const char *accountName,
                                              0, // UInt32 pathLength,
                                              NULL, // const char *path,
                                              (UInt16)[self incomingServerPort], // UInt16 port,
                                              [self incomingSecProtocolType], // SecProtocolType protocol,
                                              kSecAuthenticationTypeDefault, // SecAuthenticationType authenticationType,
                                              strlen(password), // UInt32 passwordLength,
                                              password, // const void *passwordData,
                                              NULL //SecKeychainItemRef *itemRef
                                              );
        
    }
    //if (itemRef) CFRelease(itemRef);
}

- (SecProtocolType)outgoingSecProtocolType
{
    switch ([self outgoingServerType]) 
	{
        case SMTP:
        case SMTPS:
        case SMTPTLS:
            return kSecProtocolTypeSMTP;
        default:
            return '    ';
    }    
}

- (NSString *)outgoingPasswordItemRef:(SecKeychainItemRef *)itemRef
/*" Accesses keychain to get password. "*/
{
    const char *serverName = [[self outgoingServerName] UTF8String];
    const char *accountName = [[self valueForKey: @"outgoingUsername"] UTF8String];
    UInt32 passwordLength;
    void *passwordData;
    NSString *result = nil;
    
    OSStatus err = SecKeychainFindInternetPassword(NULL, //<#CFTypeRef keychainOrArray#>
                                                   strlen(serverName), //<#UInt32 serverNameLength#>
                                                   serverName, //<#const char * serverName#>
                                                   0, //<#UInt32 securityDomainLength#>
                                                   NULL, //<#const char * securityDomain#>
                                                   strlen(accountName), //<#UInt32 accountNameLength#>
                                                   accountName, //<#const char * accountName#>
                                                   0, //<#UInt32 pathLength#>
                                                   NULL, //<#const char * path#>
                                                   (UInt16)[self outgoingServerPort], //<#UInt16 port#>
                                                   [self outgoingSecProtocolType], //<#SecProtocolType protocol#>
                                                   kSecAuthenticationTypeDefault, //<#SecAuthenticationType authenticationType#>
                                                   &passwordLength, //<#UInt32 * passwordLength#>
                                                   &passwordData, //<#void * * passwordData#>
                                                   itemRef //<#SecKeychainItemRef * itemRef#>
                                                   );
    if (err != noErr) 
	{
        if (NSDebugEnabled) NSLog(@"Error getting password from keychain (%d)", err);
    } 
	else 
	{
        NSData *data = [NSData dataWithBytes:passwordData length:passwordLength];
        result = [NSString stringWithData:data encoding:NSUTF8StringEncoding]; 
        
        err = SecKeychainItemFreeContent(NULL,           //No attribute data to release
                                         passwordData);  //Release data buffer allocated 
                                         
        if (err != noErr) 
		{
            if (NSDebugEnabled) NSLog(@"Error with getting password (%d)", err);
        }
    }
    
    return result;
}

- (NSString *)outgoingPassword
{
    SecKeychainItemRef itemRef;
    NSString *result = [self outgoingPasswordItemRef:&itemRef];
    return result;
}

- (void)setOutgoingPassword:(NSString *)aPassword
/*" Uses keychain to store password. "*/
{
    const char *serverName = [[self outgoingServerName] UTF8String];
    const char *accountName = [[self valueForKey:@"outgoingUsername"] UTF8String];
    const char *password = [aPassword UTF8String];
    OSStatus err;
    SecKeychainItemRef itemRef = NULL;
    
    if ([self outgoingPasswordItemRef:&itemRef]) 
	{        
        err = SecKeychainItemModifyAttributesAndData(itemRef, // the item reference
                                                     NULL, // no change to attributes
                                                     strlen(password),  // length of password
                                                     password); // pointer to password data
                                                     
    } 
	else 
	{
        err = SecKeychainAddInternetPassword (NULL, // SecKeychainRef keychain,
                                              strlen(serverName), // UInt32 serverNameLength,
                                              serverName, //const char *serverName,
                                              0, // UInt32 securityDomainLength,
                                              NULL, // const char *securityDomain,
                                              strlen(accountName), // UInt32 accountNameLength,
                                              accountName, // const char *accountName,
                                              0, // UInt32 pathLength,
                                              NULL, // const char *path,
                                              (UInt16)[self outgoingServerPort], // UInt16 port,
                                              [self outgoingSecProtocolType], // SecProtocolType protocol,
                                              kSecAuthenticationTypeDefault, // SecAuthenticationType authenticationType,
                                              strlen(password), // UInt32 passwordLength,
                                              password, // const void *passwordData,
                                              NULL ); //SecKeychainItemRef *itemRef
	}
}

- (int) retrieveMessageInterval 
{
	return retrieveMessageInterval;
}

- (void) setRetrieveMessageInterval: (int) value 
{
    [self willChangeValueForKey:@"retrieveMessageInterval"];
	retrieveMessageInterval = value;
    [self didChangeValueForKey:@"retrieveMessageInterval"];
}

- (int) leaveOnServerDuration 
{    
    return leaveOnServerDuration;
}

- (void)setLeaveOnServerDuration:(int)value 
{
    [self willChangeValueForKey:@"leaveOnServerDuration"];
	leaveOnServerDuration = value;
    [self didChangeValueForKey:@"leaveOnServerDuration"];
}

- (int) outgoingServerType 
{
    return outgoingServerType;
}

- (void) setOutgoingServerType:(int)value 
{
    [self willChangeValueForKey:@"outgoingServerType"];
	outgoingServerType = value;
    [self didChangeValueForKey:@"outgoingServerType"];

    [self setOutgoingServerPort: 0];
}

- (NSString *)outgoingServerName 
{
    return outgoingServerName;
}

- (void) setOutgoingServerName: (NSString*) value 
{
	if (! [outgoingServerName isEqualToString: value]) {
		[self willChangeValueForKey:@"outgoingServerName"];
		[outgoingServerName release];
		outgoingServerName = [value retain];
		[self didChangeValueForKey:@"outgoingServerName"];
	}
}

- (unsigned) outgoingServerPort 
{
    return outgoingServerPort ? outgoingServerPort : [self outgoingServerDefaultPort];
}

- (void)setOutgoingServerPort:(unsigned)value 
{
    [self willChangeValueForKey:@"outgoingServerPort"];
    outgoingServerPort = value;
    [self didChangeValueForKey:@"outgoingServerPort"];
}

- (unsigned) incomingServerPort 
{
    return incomingServerPort ? incomingServerPort : [self incomingServerDefaultPort];
}

- (void)setIncomingServerPort: (unsigned) value 
{
    [self willChangeValueForKey:@"incomingServerPort"];
    incomingServerPort = value;
    [self didChangeValueForKey:@"incomingServerPort"];
}


- (int) outgoingServerDefaultPort
{
    return [[self class] defaultPortForOutgoingServerType:[self outgoingServerType]];
}

- (int) outgoingAuthenticationMethod 
{
	return outgoingAuthenticationMethod;
}

- (void)setOutgoingAuthenticationMethod:(int)value 
{
    [self willChangeValueForKey:@"outgoingAuthenticationMethod"];
    outgoingAuthenticationMethod = value;
    [self didChangeValueForKey:@"outgoingAuthenticationMethod"];
	
#warning Add dependencies outgoingAuthenticationMethod - outgoingUsernameNeeded, outgoingUsername
    //[self willChangeValueForKey:@"outgoingUsernameNeeded"];
    //[self didChangeValueForKey:@"outgoingUsernameNeeded"];
    
    //[self willChangeValueForKey:@"outgoingUsername"];
    //[self didChangeValueForKey:@"outgoingUsername"];
}

- (BOOL) outgoingUsernameNeeded
{
    return [self outgoingAuthenticationMethod] == SMTPAuthentication;
}

/*
- (BOOL)allowExpiredSSLCertificates 
{
    NSNumber *tmpValue;
    
    [self willAccessValueForKey:@"allowExpiredSSLCertificates"];
    tmpValue = [self primitiveValueForKey:@"allowExpiredSSLCertificates"];
    [self didAccessValueForKey:@"allowExpiredSSLCertificates"];
    
    return (tmpValue != nil) ? [tmpValue boolValue] : FALSE;
}

- (void)setAllowExpiredSSLCertificates:(BOOL)value 
{
    [self willChangeValueForKey:@"allowExpiredSSLCertificates"];
    [self setPrimitiveBool:value forKey:@"allowExpiredSSLCertificates"];
    [self didChangeValueForKey:@"allowExpiredSSLCertificates"];
}

- (BOOL)allowAnyRootSSLCertificate 
{
    NSNumber *tmpValue;
    
    [self willAccessValueForKey:@"allowAnyRootSSLCertificate"];
    tmpValue = [self primitiveValueForKey:@"allowAnyRootSSLCertificate"];
    [self didAccessValueForKey:@"allowAnyRootSSLCertificate"];
    
    return (tmpValue != nil) ? [tmpValue boolValue] : FALSE;
}

- (void)setAllowAnyRootSSLCertificate:(BOOL)value 
{
    [self willChangeValueForKey:@"allowAnyRootSSLCertificate"];
    [self setPrimitiveBool:value forKey:@"allowAnyRootSSLCertificate"];
    [self didChangeValueForKey:@"allowAnyRootSSLCertificate"];
}

- (BOOL)verifySSLCertificateChain 
{
    NSNumber *tmpValue;
    
    [self willAccessValueForKey:@"verifySSLCertificateChain"];
    tmpValue = [self primitiveValueForKey:@"verifySSLCertificateChain"];
    [self didAccessValueForKey:@"verifySSLCertificateChain"];
    
    return (tmpValue != nil) ? [tmpValue boolValue] : FALSE;
}

- (void)setVerifySSLCertificateChain:(BOOL)value 
{
    [self willChangeValueForKey:@"verifySSLCertificateChain"];
    [self setPrimitiveBool:value forKey:@"verifySSLCertificateChain"];
    [self didChangeValueForKey:@"verifySSLCertificateChain"];
}
*/
- (BOOL)isPOPAccount
{
    int type = [self incomingServerType];
    
    return (type == POP3) || (type == POP3S);
}


@end

#import "GIUserDefaultsKeys.h"

@implementation GIAccount (SendingAndReceiving)

- (NSString *)dateOfLastMessageRetrievalDefaultsKey
{
	return [DateOfLastMessageRetrieval stringByAppendingString:[self objectURLString]];
}

- (NSTimeInterval)timeIntervalSinceLastMessageRetrieval
	/*" Returns the time interval since the last message retrieval if known. Returns -1.0 otherwise. "*/
{
	NSDate *dateOfLastMessageRetrieval = [[NSUserDefaults standardUserDefaults] objectForKey:[self dateOfLastMessageRetrievalDefaultsKey]];
	
	if (dateOfLastMessageRetrieval)
	{
		NSTimeInterval timeIntervalSinceNow = [dateOfLastMessageRetrieval timeIntervalSinceNow];
		
		if (timeIntervalSinceNow <= 0)
		{
			return timeIntervalSinceNow * -1.0;
		}
	}
	
	return -1.0;
}

- (void)checkpointLastMessageRetrieval
{
	[[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:[self dateOfLastMessageRetrievalDefaultsKey]];
}

+ (NSMutableArray*) timers
{
	static NSMutableArray *timers = nil;
	
	if (!timers) {
		timers = [[NSMutableArray alloc] init];
	}
	return timers;
}

- (NSTimer*) receiveTimer
/*" Returns a new autoreleased timer that is already scheduled. "*/
{
	NSTimer* result = nil;
	
	if ([[self valueForKey: @"isEnabled"] boolValue]) {
		NSTimeInterval timeIntervalSinceLastMessageRetrieval = [self timeIntervalSinceLastMessageRetrieval];
		
		NSTimeInterval interval = [[self valueForKey: @"retrieveMessageInterval"] intValue] * 60; // this might no longer be legal on Intel!
		if (interval > 0.1) {
			if (timeIntervalSinceLastMessageRetrieval > 0.0) {
				interval = MAX(0.1, interval - timeIntervalSinceLastMessageRetrieval);				
			}
			
			result = [NSTimer scheduledTimerWithTimeInterval: interval
													  target: self 
													selector: @selector(sendAndReceiveTimerFired:)
													userInfo: self 
													 repeats: NO];
		}
	}
	return result;
}

- (void) resetReceiveTimer
{	
	// find timer with userinfo == self
	NSEnumerator* enumerator = [[[self class] timers] objectEnumerator];
	NSTimer* timer;
	
	while (timer = [enumerator nextObject]) {
		if ([timer userInfo] == self) break;
	}
	
	if (timer) {
		[timer invalidate];
		[[[self class] timers] removeObjectIdenticalTo: timer];
	}
	
	if (timer = [self receiveTimer]) {
		[[[self class] timers] addObject: timer];
	}
}

+ (void) resetAccountRetrieveAndSendTimers
{
	[[self timers] makeObjectsPerformSelector: @selector(invalidate)];
	[[self timers] removeAllObjects];
	
	NSEnumerator* enumerator = [[[OPPersistentObjectContext defaultContext] allObjectsOfClass: self] objectEnumerator];
	GIAccount* account;
	
	while (account = [enumerator nextObject]) {
		NSTimer* timer = [account receiveTimer];
		
		if (timer) {
			[[self timers] addObject: timer];
		}
	}
}

- (NSArray *)messagesRipeForSendingAtTimeIntervalSinceNow:(NSTimeInterval)interval
{
    // iterate over all profiles:
	NSMutableArray *messagesQualifyingForSend = [NSMutableArray array];
    NSEnumerator *enumerator = [[[OPPersistentObjectContext defaultContext] allObjectsOfClass: [GIProfile class]] objectEnumerator];
    GIProfile *profile;
    
    while (profile = [enumerator nextObject]) 
	{
		if ([profile valueForKey:@"sendAccount"] == self)
		{
			NSEnumerator *messagesToSendEnumerator = [[profile valueForKey:@"messagesToSend"] objectEnumerator];
			GIMessage *message;
			NSDate *ripeDate = [NSDate dateWithTimeIntervalSinceNow:interval];
			
			while (message = [messagesToSendEnumerator nextObject]) 
			{
				NSDate *earliestSendTime = [message earliestSendTime];
				BOOL timeIsRipe = YES;
				
				if (earliestSendTime)
				{
					if ([earliestSendTime laterDate:ripeDate] == earliestSendTime)
					{
						timeIsRipe = NO;
					}
				}
				
				if (([message sendStatus] == OPSendStatusQueuedReady) && (timeIsRipe)) 
				{
					[messagesQualifyingForSend addObject:message];
				}
			}
		}
    }
	
	return messagesQualifyingForSend;
}

+ (BOOL) anyMessagesRipeForSendingAtTimeIntervalSinceNow: (NSTimeInterval) interval
{
	NSEnumerator* enumerator = [[[OPPersistentObjectContext defaultContext] allObjectsOfClass: self] objectEnumerator];
	GIAccount* account;
	
	while (account = [enumerator nextObject]) {
		if ([[account messagesRipeForSendingAtTimeIntervalSinceNow:interval] count]) {
			return YES;
		}
	}
	
	return NO;
}

//- (void)sendMessagesRipeForSendingAtTimeIntervalSinceNow:(NSTimeInterval)interval
//{
//	NSArray *messagesQualifyingForSend = [self messagesRipeForSendingAtTimeIntervalSinceNow:interval];
//	
//	// something to send for the account?
//	if ([messagesQualifyingForSend count]) 
//	{
//		NSEnumerator *enumerator = [messagesQualifyingForSend objectEnumerator];
//		GIMessage *message;
//		while (message = [enumerator nextObject])
//		{
//			[message setSendStatus:OPSendStatusSending];
//		}
//
//		[GISMTPJob sendMessages:messagesQualifyingForSend viaSMTPAccount:self];
//	}
//}

- (void)send
{
	[self sendMessagesRipeForSendingAtTimeIntervalSinceNow:0.0];
}

//- (void)receive
///*" Starts an asynchronous receive job for the receiver. "*/
//{
//	if ([[self valueForKey:@"isEnabled"] boolValue] && [self isPOPAccount]) 
//	{
//		[self checkpointLastMessageRetrieval];
//		[GIPOPJob retrieveMessagesFromPOPAccount:self];
//	}
//}

- (void)sendAndReceiveTimerFired:(NSTimer *)aTimer
{
	[self receive];
	[self send];
	[self resetReceiveTimer];
}

- (void)didChangeValueForKey:(NSString *)key
{
	[super didChangeValueForKey:key];
	
	if ([key isEqualToString:@"retrieveMessageInterval"])
	{
		[[self class] resetAccountRetrieveAndSendTimers];
	}
}

@end