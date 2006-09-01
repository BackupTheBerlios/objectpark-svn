//
//  GIAccount.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 18.10.05.
//  Copyright 2005 The Objectpark Group. All rights reserved.
//

#import "GIAccount.h"
#import "OPPersistentObject+Extensions.h"
#import <Security/Security.h>
#import <Foundation/NSDebug.h>
#import "NSString+Extensions.h"
#import "GIPOPJob.h"
#import "GISMTPJob.h"
#import "GIApplication.h"
#import "GIProfile.h"
#import "GIMessage.h"

@implementation GIAccount

+ (NSString *)databaseProperties
{
	return 
	@"{"
	@"  TableName = ZACCOUNT;"
	@"  CacheAllObjects = 1;"
	@"  CreateStatements = (\""
	@"  CREATE TABLE ZACCOUNT ( Z_ENT INTEGER, Z_PK INTEGER PRIMARY KEY, Z_OPT INTEGER, ZINCOMINGUSERNAME VARCHAR, ZOUTGOINGUSERNAME VARCHAR, ZRETRIEVEMESSAGEINTERVAL INTEGER, ZALLOWEXPIREDSSLCERTIFICATES INTEGER, ZLEAVEONSERVERDURATION INTEGER, ZOUTGOINGAUTHENTICATIONMETHOD INTEGER, ZINCOMINGSERVERPORT INTEGER, ZOUTGOINGSERVERPORT INTEGER, ZVERIFYSSLCERTIFICATECHAIN INTEGER, ZOUTGOINGSERVERNAME VARCHAR, ZINCOMINGSERVERNAME VARCHAR, ZINCOMINGSERVERTYPE INTEGER, ZALLOWANYROOTSSLCERTIFICATE INTEGER, ZNAME VARCHAR, ZINCOMINGAUTHENTICATIONMETHOD INTEGER, ZOUTGOINGSERVERTYPE INTEGER , ZISENABLED INTEGER)"
	@"  \");"
	@""
	@"}";
}

+ (NSString *)persistentAttributesPlist
{
	return 
	@"{"
	@"incomingUsername = {ColumnName = ZINCOMINGUSERNAME; AttributeClass = NSString;};"
	@"outgoingUsername = {ColumnName = ZOUTGOINGUSERNAME; AttributeClass = NSString;};"
	@"retrieveMessageInterval = {ColumnName = ZRETRIEVEMESSAGEINTERVAL; AttributeClass = NSNumber;};"
	@"allowExpiredSSLCertificates = {ColumnName = ZALLOWEXPIREDSSLCERTIFICATES; AttributeClass = NSNumber;};"
	@"leaveOnServerDuration = {ColumnName = ZLEAVEONSERVERDURATION; AttributeClass = NSNumber;};"
	@"outgoingAuthenticationMethod = {ColumnName = ZOUTGOINGAUTHENTICATIONMETHOD; AttributeClass = NSNumber;};"
	@"incomingServerPort = {ColumnName = ZINCOMINGSERVERPORT; AttributeClass = NSNumber;};"
	@"verifySSLCertificateChain = {ColumnName = ZVERIFYSSLCERTIFICATECHAIN; AttributeClass = NSNumber;};"
	@"outgoingServerName = {ColumnName = ZOUTGOINGSERVERNAME; AttributeClass = NSString;};"
	@"incomingServerName = {ColumnName = ZINCOMINGSERVERNAME; AttributeClass = NSString;};"
	@"incomingServerType = {ColumnName = ZINCOMINGSERVERTYPE; AttributeClass = NSNumber;};"
	@"allowAnyRootSSLCertificate = {ColumnName = ZALLOWANYROOTSSLCERTIFICATE; AttributeClass = NSNumber;};"
	@"outgoingServerType = {ColumnName = ZOUTGOINGSERVERTYPE; AttributeClass = NSNumber;};"
	@"isEnabled = {ColumnName = ZISENABLED; AttributeClass = NSNumber;};"
	@"name = {ColumnName = ZNAME; AttributeClass = NSString;};"
	@"incomingAuthenticationMethod = {ColumnName = ZINCOMINGAUTHENTICATIONMETHOD; AttributeClass = NSNumber;};"
	@"profiles = {InverseRelationshipKey = sendAccount; AttributeClass = GIProfile; QueryString =\"select ZPROFILE.ROWID from ZPROFILE where ZSENDACCOUNT=?1\";};"
	@"}";
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
/*" Designated initializer. Also inserts the receiver into the main thread context. "*/
{
	if (self = [super init]) 
    {
	}
	return self;
}

- (void)insertIntoContext:(OPPersistentObjectContext *)aContext
/*" Setting default value. "*/
{
    [super insertIntoContext:aContext];
	[self setValue:[NSNumber numberWithBool:YES] forKey:@"verifySSLCertificateChain"];
}

- (void)dealloc
{
    [super dealloc];
}

- (NSString *)name 
{
    NSString *tmpValue;
    
    [self willAccessValueForKey:@"name"];
    tmpValue = [self primitiveValueForKey:@"name"];
    [self didAccessValueForKey:@"name"];
    
    return tmpValue;
}

- (void)setName:(NSString *)value 
{
    [self willChangeValueForKey:@"name"];
    [self setPrimitiveValue:value forKey:@"name"];
    [self didChangeValueForKey:@"name"];
}

/*
- (BOOL)isEnabled 
{
    NSNumber *tmpValue;
    
    [self willAccessValueForKey:@"isEnabled"];
    tmpValue = [self primitiveValueForKey:@"isEnabled"];
    [self didAccessValueForKey:@"isEnabled"];
    
    return (tmpValue != nil) ? [tmpValue boolValue] : FALSE;
}

- (void)setIsEnabled:(BOOL)value 
{
    [self willChangeValueForKey:@"isEnabled"];
    [self setPrimitiveBool:value forKey:@"isEnabled"];
    [self didChangeValueForKey:@"isEnabled"];
}
*/
- (int)incomingServerType 
{
    NSNumber *tmpValue;
    
    [self willAccessValueForKey:@"incomingServerType"];
    tmpValue = [self primitiveValueForKey:@"incomingServerType"];
    [self didAccessValueForKey:@"incomingServerType"];
    
    return (tmpValue != nil) ? [tmpValue intValue] : 0;
}

- (void)setIncomingServerType:(int)value 
{
    [self willChangeValueForKey:@"incomingServerType"];
    [self setPrimitiveValue:[NSNumber numberWithInt:value] forKey:@"incomingServerType"];
    [self didChangeValueForKey:@"incomingServerType"];

    [self willChangeValueForKey:@"POPAccount"]; // signalling -isPOPAccount changed
    [self didChangeValueForKey:@"POPAccount"];	

    // A change of the server type also has effect on the port. The Account is 'touched' to have bindings recognize the change.
    [self setIncomingServerPort:0];
    [self willChangeValueForKey:@"incomingServerDefaultPort"];
    [self didChangeValueForKey:@"incomingServerDefaultPort"];
    
    if (![self isPOPAccount])
    {
        if ([self incomingAuthenticationMethod] != PlainText)
        {
            [self setIncomingAuthenticationMethod:PlainText];
        }
    }
}

- (NSString *)incomingServerName 
{
    NSString *tmpValue;
    
    [self willAccessValueForKey:@"incomingServerName"];
    tmpValue = [self primitiveValueForKey:@"incomingServerName"];
    [self didAccessValueForKey:@"incomingServerName"];
    
    return tmpValue;
}

- (void)setIncomingServerName:(NSString *)value 
{
    [self willChangeValueForKey:@"incomingServerName"];
    [self setPrimitiveValue:value forKey:@"incomingServerName"];
    [self didChangeValueForKey:@"incomingServerName"];
}

- (int)incomingServerPort 
{
    NSNumber *tmpValue;
    
    [self willAccessValueForKey:@"incomingServerPort"];
    tmpValue = [self primitiveValueForKey:@"incomingServerPort"];
    [self didAccessValueForKey:@"incomingServerPort"];
    
    int result = (tmpValue != nil) ? [tmpValue intValue] : 0;
    return result ? result : [[self class] defaultPortForIncomingServerType:[self incomingServerType]];
}

- (void)setIncomingServerPort:(int)value 
{
    [self willChangeValueForKey:@"incomingServerPort"];
    [self setPrimitiveValue:[NSNumber numberWithInt:value] forKey:@"incomingServerPort"];
    [self didChangeValueForKey:@"incomingServerPort"];
}

- (int)incomingServerDefaultPort
{
    return [[self class] defaultPortForIncomingServerType:[self incomingServerType]];
}

- (int)incomingAuthenticationMethod 
{
    NSNumber *tmpValue;
    
    [self willAccessValueForKey:@"incomingAuthenticationMethod"];
    tmpValue = [self primitiveValueForKey:@"incomingAuthenticationMethod"];
    [self didAccessValueForKey:@"incomingAuthenticationMethod"];
    
    return (tmpValue != nil) ? [tmpValue intValue] : 0;
}

- (void)setIncomingAuthenticationMethod:(int)value 
{
    [self willChangeValueForKey:@"incomingAuthenticationMethod"];
    [self setPrimitiveValue:[NSNumber numberWithInt:value] forKey:@"incomingAuthenticationMethod"];
    [self didChangeValueForKey:@"incomingAuthenticationMethod"];
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

- (int)retrieveMessageInterval 
{
    NSNumber *tmpValue;
    
    [self willAccessValueForKey:@"retrieveMessageInterval"];
    tmpValue = [self primitiveValueForKey:@"retrieveMessageInterval"];
    [self didAccessValueForKey:@"retrieveMessageInterval"];
    
    return (tmpValue != nil) ? [tmpValue intValue] : 0;
}

- (void)setRetrieveMessageInterval:(int)value 
{
    [self willChangeValueForKey:@"retrieveMessageInterval"];
    [self setPrimitiveValue:[NSNumber numberWithInt:value]
                     forKey:@"retrieveMessageInterval"];
    [self didChangeValueForKey:@"retrieveMessageInterval"];
}

- (int)leaveOnServerDuration 
{
    NSNumber *tmpValue;
    
    [self willAccessValueForKey:@"leaveOnServerDuration"];
    tmpValue = [self primitiveValueForKey:@"leaveOnServerDuration"];
    [self didAccessValueForKey:@"leaveOnServerDuration"];
    
    return (tmpValue != nil) ? [tmpValue intValue] : 0;
}

- (void)setLeaveOnServerDuration:(int)value 
{
    [self willChangeValueForKey:@"leaveOnServerDuration"];
    [self setPrimitiveValue:[NSNumber numberWithInt:value]
                     forKey:@"leaveOnServerDuration"];
    [self didChangeValueForKey:@"leaveOnServerDuration"];
}

- (int) outgoingServerType 
{
    NSNumber *tmpValue;
    
    [self willAccessValueForKey:@"outgoingServerType"];
    tmpValue = [self primitiveValueForKey:@"outgoingServerType"];
    [self didAccessValueForKey:@"outgoingServerType"];
    
    return (tmpValue != nil) ? [tmpValue intValue] : 0;
}

- (void) setOutgoingServerType:(int)value 
{
    [self willChangeValueForKey:@"outgoingServerType"];
    [self setPrimitiveValue:[NSNumber numberWithInt:value]
                     forKey:@"outgoingServerType"];
    [self didChangeValueForKey:@"outgoingServerType"];

    [self setOutgoingServerPort:0];
    [self willChangeValueForKey:@"outgoingServerDefaultPort"];
    [self didChangeValueForKey:@"outgoingServerDefaultPort"];	
}

- (NSString *)outgoingServerName 
{
    NSString *tmpValue;
    
    [self willAccessValueForKey:@"outgoingServerName"];
    tmpValue = [self primitiveValueForKey:@"outgoingServerName"];
    [self didAccessValueForKey:@"outgoingServerName"];
    
    return tmpValue;
}

- (void)setOutgoingServerName:(NSString *)value 
{
    [self willChangeValueForKey:@"outgoingServerName"];
    [self setPrimitiveValue:value forKey:@"outgoingServerName"];
    [self didChangeValueForKey:@"outgoingServerName"];
}

- (int)outgoingServerPort 
{
    NSNumber *tmpValue;
    
    [self willAccessValueForKey:@"outgoingServerPort"];
    tmpValue = [self primitiveValueForKey:@"outgoingServerPort"];
    [self didAccessValueForKey:@"outgoingServerPort"];
    
    int result = (tmpValue != nil) ? [tmpValue intValue] : 0;
    return result ? result : [[self class] defaultPortForOutgoingServerType:[self outgoingServerType]];
}

- (void)setOutgoingServerPort:(int)value 
{
    [self willChangeValueForKey:@"outgoingServerPort"];
    [self setPrimitiveValue:[NSNumber numberWithInt:value] forKey:@"outgoingServerPort"];
    [self didChangeValueForKey:@"outgoingServerPort"];
}

- (int)outgoingServerDefaultPort
{
    return [[self class] defaultPortForOutgoingServerType:[self outgoingServerType]];
}

- (int)outgoingAuthenticationMethod 
{
    NSNumber *tmpValue;
    
    [self willAccessValueForKey:@"outgoingAuthenticationMethod"];
    tmpValue = [self primitiveValueForKey:@"outgoingAuthenticationMethod"];
    [self didAccessValueForKey:@"outgoingAuthenticationMethod"];
    
    return (tmpValue != nil) ? [tmpValue intValue] : 0;
}

- (void)setOutgoingAuthenticationMethod:(int)value 
{
    [self willChangeValueForKey:@"outgoingAuthenticationMethod"];
    [self setPrimitiveValue:[NSNumber numberWithInt:value] forKey:@"outgoingAuthenticationMethod"];
    [self didChangeValueForKey:@"outgoingAuthenticationMethod"];
	
    [self willChangeValueForKey:@"outgoingUsernameNeeded"];
    [self didChangeValueForKey:@"outgoingUsernameNeeded"];
    
    [self willChangeValueForKey:@"outgoingUsername"];
    [self didChangeValueForKey:@"outgoingUsername"];
}

- (BOOL)outgoingUsernameNeeded
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

+ (void)resetAccountRetrieveAndSendTimers
{
	static NSMutableArray *timers = nil;
	
	if (!timers)
	{
		timers = [[NSMutableArray alloc] init];
	}
	else
	{
		[timers makeObjectsPerformSelector:@selector(invalidate)];
		[timers removeAllObjects];
	}
	
	NSEnumerator *enumerator = [[self allObjects] objectEnumerator];
	GIAccount *account;
	
	while (account = [enumerator nextObject])
	{
		NSTimeInterval timeIntervalSinceLastMessageRetrieval = [account timeIntervalSinceLastMessageRetrieval];
		
		NSTimeInterval interval = [[account valueForKey:@"retrieveMessageInterval"] floatValue] * 60.0;
		if (interval > 0.1)
		{
			if (timeIntervalSinceLastMessageRetrieval > 0.0)
			{
				interval = interval - timeIntervalSinceLastMessageRetrieval;
				
				if (interval < 0.1) interval = 0.1;
			}
			
			NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:interval target:account selector:@selector(sendAndReceiveTimerFired:) userInfo:nil repeats:YES];
			[timers addObject:timer];
		}
	}
}

- (NSArray *)messagesRipeForSendingAtTimeIntervalSinceNow:(NSTimeInterval)interval
{
    // iterate over all profiles:
	NSMutableArray *messagesQualifyingForSend = [NSMutableArray array];
    NSEnumerator *enumerator = [[GIProfile allObjects] objectEnumerator];
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

+ (BOOL)anyMessagesRipeForSendingAtTimeIntervalSinceNow:(NSTimeInterval)interval
{
	NSEnumerator *enumerator = [[GIAccount allObjects] objectEnumerator];
	GIAccount *account;
	
	while (account = [enumerator nextObject])
	{
		if ([[account messagesRipeForSendingAtTimeIntervalSinceNow:interval] count])
		{
			return YES;
		}
	}
	
	return NO;
}

- (void)sendMessagesRipeForSendingAtTimeIntervalSinceNow:(NSTimeInterval)interval
{
	NSArray *messagesQualifyingForSend = [self messagesRipeForSendingAtTimeIntervalSinceNow:interval];
	
	// something to send for the account?
	if ([messagesQualifyingForSend count]) 
	{
		NSEnumerator *enumerator = [messagesQualifyingForSend objectEnumerator];
		GIMessage *message;
		while (message = [enumerator nextObject])
		{
			[message setSendStatus:OPSendStatusSending];
		}

		[GISMTPJob sendMessages:messagesQualifyingForSend viaSMTPAccount:self];
	}
}

- (void)send
{
	[self sendMessagesRipeForSendingAtTimeIntervalSinceNow:0.0];
}

- (void)receive
/*" Starts an asynchronous receive job for the receiver. "*/
{
	if ([[self valueForKey:@"isEnabled"] boolValue] && [self isPOPAccount]) 
	{
		[self checkpointLastMessageRetrieval];
		[GIPOPJob retrieveMessagesFromPOPAccount:self];
	}
}

- (void)sendAndReceiveTimerFired:(NSTimer *)aTimer
{
	[self receive];
	[self send];
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