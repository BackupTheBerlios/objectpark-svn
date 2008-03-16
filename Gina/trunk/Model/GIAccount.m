//
//  GIAccount.m
//  Gina
//
//  Created by Dirk Theisen on 18.10.05.
//  Revised by Axel Katerbau on 25.12.07.
//  Copyright 2005 The Objectpark Group. All rights reserved.
//

#import "GIAccount.h"
#import <Security/Security.h>
#import <Foundation/NSDebug.h>
#import "NSString+Extensions.h"
#import "GIPOPOperation.h"
//#import "GISMTPJob.h"
#import "GIApplication.h"
#import "GIProfile.h"
#import "GIMessage.h"
#import "OPPersistence.h"

@implementation GIAccount

+ (BOOL)cachesAllObjects
{
	return YES;
}

+ (NSSet *)keyPathsForValuesAffectingPOPAccount
{
	return [NSSet setWithObject:@"incomingServerType"];
}

+ (NSSet *)keyPathsForValuesAffectingOutgoingUsernameNeeded
{
	return [NSSet setWithObject:@"outgoingAuthenticationMethod"];
}

+ (NSSet *)keyPathsForValuesAffectingOutgoingUsername
{
	return [NSSet setWithObject:@"outgoingAuthenticationMethod"];
}

+ (NSSet *)keyPathsForValuesAffectingIncomingServerDefaultPort
{
	return [NSSet setWithObject:@"incomingServerType"];
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
	if (self = [super init]) 
	{
		verifySSLCertificateChain = YES;
	}
	return self;
}


- (void)dealloc
{
	[name release];
	[incomingUsername release];
	[outgoingUsername release];
	[outgoingServerName release];
	[incomingServerName release];
	[profiles release];

    [super dealloc];
}

- (BOOL)enabled
{
	return enabled;
}

- (void)setEnabled:(BOOL)aBool
{
	[self willChangeValueForKey:@"enabled"];
	enabled = aBool;
	[self didChangeValueForKey:@"enabled"];
}

- (NSString *)name
{
	return name;
}

- (void)setName:(NSString *)aName
{
	[self willChangeValueForKey:@"name"];
	[name autorelease];
	name = [aName copy];
	[self didChangeValueForKey:@"name"];
}

- (int)incomingServerType 
{
	return incomingServerType;
}

- (void)setIncomingServerType:(int)value 
{
    [self willChangeValueForKey:@"incomingServerType"];

    // A change of the server type also has effect on the port. The Account is 'touched' to have bindings recognize the change.
    [self setIncomingServerPort:0];
	incomingServerType = value;
    
    if (![self isPOPAccount]) 
	{
        if ([self incomingAuthenticationMethod] != PlainText)
        {
            [self setIncomingAuthenticationMethod:PlainText];
        }
    }
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
    const char *serverName = [self.outgoingServerName UTF8String];
    const char *accountName = [self.outgoingUsername UTF8String];
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

- (int)retrieveMessageInterval 
{
	return retrieveMessageInterval;
}

- (void)setRetrieveMessageInterval:(int)value 
{
    [self willChangeValueForKey:@"retrieveMessageInterval"];
	retrieveMessageInterval = value;
    [self didChangeValueForKey:@"retrieveMessageInterval"];
}

- (int)leaveOnServerDuration 
{    
    return leaveOnServerDuration;
}

- (void)setLeaveOnServerDuration:(int)value 
{
    [self willChangeValueForKey:@"leaveOnServerDuration"];
	leaveOnServerDuration = value;
    [self didChangeValueForKey:@"leaveOnServerDuration"];
}

- (int)outgoingServerType 
{
    return outgoingServerType;
}

- (void)setOutgoingServerType:(int)value 
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

- (void)setOutgoingServerName:(NSString *)value 
{
	if (! [outgoingServerName isEqualToString:value]) 
	{
		[self willChangeValueForKey:@"outgoingServerName"];
		[outgoingServerName release];
		outgoingServerName = [value retain];
		[self didChangeValueForKey:@"outgoingServerName"];
	}
}

- (NSString *)outgoingUsername
{
	return outgoingUsername;
}

- (void)setOutgoingUsername:(NSString *)aName
{
	if (![aName isEqualToString:outgoingUsername])
	{
		[self willChangeValueForKey:@"outgoingUsername"];
		[outgoingUsername release];
		outgoingUsername = [aName copy];
		[self didChangeValueForKey:@"outgoingUsername"];
	}
}

- (unsigned)outgoingServerPort 
{
    return outgoingServerPort ? outgoingServerPort : [self outgoingServerDefaultPort];
}

- (void)setOutgoingServerPort:(unsigned)value 
{
    [self willChangeValueForKey:@"outgoingServerPort"];
    outgoingServerPort = value;
    [self didChangeValueForKey:@"outgoingServerPort"];
}

- (NSString *)incomingServerName
{
	return incomingServerName;
}

- (void)setIncomingServerName:(NSString *)aName
{
	if (![aName isEqualToString:incomingServerName])
	{
		[self willChangeValueForKey:@"incomingServerName"];
		[incomingServerName release];
		incomingServerName = [aName copy];
		[self didChangeValueForKey:@"incomingServerName"];
	}
}

- (unsigned)incomingServerPort 
{
    return incomingServerPort ? incomingServerPort : [self incomingServerDefaultPort];
}

- (void)setIncomingServerPort:(unsigned)value 
{
    [self willChangeValueForKey:@"incomingServerPort"];
    incomingServerPort = value;
    [self didChangeValueForKey:@"incomingServerPort"];
}

- (NSString *)incomingUsername
{
	return incomingUsername;
}

- (void)setIncomingUsername:(NSString *)aName
{
	if (![aName isEqualToString:incomingUsername])
	{
		[self willChangeValueForKey:@"incomingUsername"];
		[incomingUsername release];
		incomingUsername = [aName copy];
		[self didChangeValueForKey:@"incomingUsername"];
	}
}

- (int)incomingAuthenticationMethod
{
	return incomingAuthenticationMethod;
}

- (void)setIncomingAuthenticationMethod:(int)aMethod
{
	if (aMethod != incomingAuthenticationMethod)
	{
		[self willChangeValueForKey:@"incomingAuthenticationMethod"];
		incomingAuthenticationMethod = aMethod;
		[self didChangeValueForKey:@"incomingAuthenticationMethod"];
	}
}

- (int)incomingServerDefaultPort
{
    return [[self class] defaultPortForIncomingServerType:self.incomingServerType];
}

- (int)outgoingServerDefaultPort
{
    return [[self class] defaultPortForOutgoingServerType:self.outgoingServerType];
}

- (int)outgoingAuthenticationMethod 
{
	return outgoingAuthenticationMethod;
}

- (void)setOutgoingAuthenticationMethod:(int)value 
{
    [self willChangeValueForKey:@"outgoingAuthenticationMethod"];
    outgoingAuthenticationMethod = value;
    [self didChangeValueForKey:@"outgoingAuthenticationMethod"];
}

- (BOOL)outgoingUsernameNeeded
{
    return [self outgoingAuthenticationMethod] == SMTPAuthentication;
}

- (BOOL)allowExpiredSSLCertificates 
{
	return allowExpiredSSLCertificates;
}

- (void)setAllowExpiredSSLCertificates:(BOOL)value 
{
    [self willChangeValueForKey:@"allowExpiredSSLCertificates"];
	allowExpiredSSLCertificates = value;
    [self didChangeValueForKey:@"allowExpiredSSLCertificates"];
}

- (BOOL)allowAnyRootSSLCertificate 
{
	return allowAnyRootSSLCertificate;
}

- (void)setAllowAnyRootSSLCertificate:(BOOL)value 
{
    [self willChangeValueForKey:@"allowAnyRootSSLCertificate"];
	allowAnyRootSSLCertificate = value;
    [self didChangeValueForKey:@"allowAnyRootSSLCertificate"];
}

- (BOOL)verifySSLCertificateChain 
{
	return verifySSLCertificateChain;
}

- (void)setVerifySSLCertificateChain:(BOOL)value 
{
    [self willChangeValueForKey:@"verifySSLCertificateChain"];
	verifySSLCertificateChain = value;
    [self didChangeValueForKey:@"verifySSLCertificateChain"];
}

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

/*" Returns the time interval since the last message retrieval if known. Returns -1.0 otherwise. "*/
- (NSTimeInterval)timeIntervalSinceLastMessageRetrieval
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

+ (NSMutableArray *)timers
{
	static NSMutableArray *timers = nil;
	
	if (!timers) 
	{
		timers = [[NSMutableArray alloc] init];
	}
	return timers;
}

/*" Returns a new autoreleased timer that is already scheduled. "*/
- (NSTimer *)receiveTimer
{
	NSTimer *result = nil;
	
	if (self.enabled) 
	{
		NSTimeInterval timeIntervalSinceLastMessageRetrieval = [self timeIntervalSinceLastMessageRetrieval];
		
		NSTimeInterval interval = self.retrieveMessageInterval * 60.0;
		
		if (interval > 0.1) 
		{
			if (timeIntervalSinceLastMessageRetrieval > 0.0) 
			{
				interval = MAX(0.1, interval - timeIntervalSinceLastMessageRetrieval);				
			}
			
			result = [NSTimer scheduledTimerWithTimeInterval:interval
													  target:self 
													selector:@selector(sendAndReceiveTimerFired:)
													userInfo:self 
													 repeats:NO];
		}
	}
	
	return result;
}

- (void)resetReceiveTimer
{	
	// find timer with userinfo == self
	NSTimer *timer = nil;
	for (timer in [[self class] timers])
	{
		if ([timer userInfo] == self) break;
	}
	
	if (timer) 
	{
		[timer invalidate];
		[[[self class] timers] removeObjectIdenticalTo:timer];
	}
	
	if (timer = [self receiveTimer]) 
	{
		[[[self class] timers] addObject:timer];
	}
}

+ (void)resetAccountRetrieveAndSendTimers
{
	[[self timers] makeObjectsPerformSelector:@selector(invalidate)];
	[[self timers] removeAllObjects];
	
	for (GIAccount *account in [[OPPersistentObjectContext defaultContext] allObjectsOfClass:self])
	{
		NSTimer *timer = [account receiveTimer];
		
		if (timer) 
		{
			[[self timers] addObject: timer];
		}
	}
}

- (NSArray *)messagesRipeForSendingAtTimeIntervalSinceNow:(NSTimeInterval)interval
{
    // iterate over all profiles:
	NSMutableArray *messagesQualifyingForSend = [NSMutableArray array];
	
	for (GIProfile *profile in [[OPPersistentObjectContext defaultContext] allObjectsOfClass:[GIProfile class]])
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

+ (BOOL)anyMessagesRipeForSendingAtTimeIntervalSinceNow:(NSTimeInterval)interval
{
	for (GIAccount *account in [[OPPersistentObjectContext defaultContext] allObjectsOfClass:self])
	{
		if ([[account messagesRipeForSendingAtTimeIntervalSinceNow:interval] count]) 
		{
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

- (void)receive
/*" Starts an asynchronous receive job for the receiver. "*/
{
	if (self.enabled && [self isPOPAccount]) 
	{
		[self checkpointLastMessageRetrieval];
		
		[GIPOPOperation retrieveMessagesFromPOPAccount:self usingOperationQueue:[GIApp operationQueue]];
	}
}

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

@implementation GIAccount (Coding)

- (id)initWithCoder:(NSCoder *)coder
{
	enabled = [coder decodeBoolForKey:@"enabled"];
	name = [coder decodeObjectForKey:@"name"];
	incomingUsername = [coder decodeObjectForKey:@"incomingUsername"];
	outgoingUsername = [coder decodeObjectForKey:@"outgoingUsername"];
	retrieveMessageInterval = [coder decodeInt32ForKey:@"retrieveMessageInterval"];

	leaveOnServerDuration = [coder decodeInt32ForKey:@"leaveOnServerDuration"];
	outgoingAuthenticationMethod = [coder decodeInt32ForKey:@"outgoingAuthenticationMethod"];
	incomingServerPort = [coder decodeInt32ForKey:@"incomingServerPort"];
	outgoingServerPort = [coder decodeInt32ForKey:@"outgoingServerPort"];
	outgoingServerName = [coder decodeObjectForKey:@"outgoingServerName"];
	outgoingServerType = [coder decodeInt32ForKey:@"outgoingServerType"];
	incomingServerName = [coder decodeObjectForKey:@"incomingServerName"];
	incomingServerType = [coder decodeInt32ForKey:@"incomingServerType"];
	incomingAuthenticationMethod = [coder decodeInt32ForKey:@"incomingAuthenticationMethod"];
	
	allowAnyRootSSLCertificate = [coder decodeBoolForKey:@"allowAnyRootSSLCertificate"];
	allowExpiredSSLCertificates = [coder decodeBoolForKey:@"allowExpiredSSLCertificates"];
	verifySSLCertificateChain = [coder decodeBoolForKey:@"verifySSLCertificateChain"];
	
	profiles = [coder decodeObjectForKey:@"profiles"];
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeBool:enabled forKey:@"enabled"];
	[coder encodeObject:name forKey:@"name"];
	[coder encodeObject:incomingUsername forKey:@"incomingUsername"];
	[coder encodeObject:outgoingUsername forKey:@"outgoingUsername"];
	[coder encodeInt32:retrieveMessageInterval forKey:@"retrieveMessageInterval"];
	
	[coder encodeInt32:leaveOnServerDuration forKey:@"leaveOnServerDuration"];
	[coder encodeInt32:outgoingAuthenticationMethod forKey:@"outgoingAuthenticationMethod"];
	[coder encodeInt32:incomingServerPort forKey:@"incomingServerPort"];
	[coder encodeInt32:outgoingServerPort forKey:@"outgoingServerPort"];
	[coder encodeObject:outgoingServerName forKey:@"outgoingServerName"];
	[coder encodeInt32:outgoingServerType forKey:@"outgoingServerType"];
	[coder encodeObject:incomingServerName forKey:@"incomingServerName"];
	[coder encodeInt32:incomingServerType forKey:@"incomingServerType"];
	[coder encodeInt32:incomingAuthenticationMethod forKey:@"incomingAuthenticationMethod"];
	
	[coder encodeBool:allowAnyRootSSLCertificate forKey:@"allowAnyRootSSLCertificate"];
	[coder encodeBool:allowExpiredSSLCertificates forKey:@"allowExpiredSSLCertificates"];
	[coder encodeBool:verifySSLCertificateChain forKey:@"verifySSLCertificateChain"];
	
	[coder encodeObject:profiles forKey:@"profiles"];
}

@end