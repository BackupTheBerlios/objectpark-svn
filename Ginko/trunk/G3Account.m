//
//  G3Account.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 25.02.05.
//  Copyright 2005 Objectpark Group. All rights reserved.
//

#import "G3Account.h"
#import "NSManagedObjectContext+Extensions.h"
#include <CoreFoundation/CoreFoundation.h>
#include <Security/Security.h>
#include <CoreServices/CoreServices.h>
#include "NSString+Extensions.h"
#include <Foundation/NSDebug.h>

@implementation G3Account

+ (NSArray *)accounts
{    
	NSArray *result;
	
    result = [self allObjects];
	
	if (![result count])
	{
		[[[self alloc] init] autorelease];
		result = [self allObjects];
	}
	
	return result;
}

+ (void)setAccounts:(NSArray *)someAccounts
{
	/*
    [allAccounts autorelease];
    allAccounts = [someAccounts retain];
    [self commitAccounts];
	 */
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
/*" Designated initializer "*/
{
    return [self initWithManagedObjectContext:[NSManagedObjectContext defaultContext]];
}

- (void)dealloc
{
    [super dealloc];
}

- (NSString *)name 
{
    NSString * tmpValue;
    
    [self willAccessValueForKey:@"name"];
    tmpValue = [self primitiveValueForKey:@"name"];
    [self didAccessValueForKey:@"name"];
    
    return tmpValue;
}

- (void)setName:(NSString *)value 
{
    [self willChangeValueForKey:@"name"];
    [self setPrimitiveValue: value forKey:@"name"];
    [self didChangeValueForKey:@"name"];
}

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
    [self setPrimitiveValue:[NSNumber numberWithBool:value]
                     forKey:@"isEnabled"];
    [self didChangeValueForKey:@"isEnabled"];
}

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
    [self setPrimitiveValue:[NSNumber numberWithInt:value]
                     forKey:@"incomingServerType"];
    [self didChangeValueForKey:@"incomingServerType"];

    [self setIncomingServerPort:0];
    [self willChangeValueForKey:@"incomingServerDefaultPort"];
    [self didChangeValueForKey:@"incomingServerDefaultPort"];
    [self willChangeValueForKey:@"POPAccount"];
    [self didChangeValueForKey:@"POPAccount"];	
}

- (NSString *)incomingServerName 
{
    NSString * tmpValue;
    
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
    
    [self willAccessValueForKey: @"incomingServerPort"];
    tmpValue = [self primitiveValueForKey: @"incomingServerPort"];
    [self didAccessValueForKey: @"incomingServerPort"];
    
    int result = (tmpValue != nil) ? [tmpValue intValue] : 0;
    return result ? result : [[self class] defaultPortForIncomingServerType:[self incomingServerType]];
}

- (void)setIncomingServerPort:(int)value 
{
    [self willChangeValueForKey: @"incomingServerPort"];
    [self setPrimitiveValue: [NSNumber numberWithInt: value]
                     forKey: @"incomingServerPort"];
    [self didChangeValueForKey: @"incomingServerPort"];
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
    [self setPrimitiveValue:[NSNumber numberWithInt: value]
                     forKey:@"incomingAuthenticationMethod"];
    [self didChangeValueForKey:@"incomingAuthenticationMethod"];
}

- (NSString *)incomingUsername 
{
    NSString * tmpValue;
    
    [self willAccessValueForKey:@"incomingUsername"];
    tmpValue = [self primitiveValueForKey:@"incomingUsername"];
    [self didAccessValueForKey:@"incomingUsername"];
    
    return tmpValue;
}

- (void)setIncomingUsername:(NSString *)value 
{
    [self willChangeValueForKey:@"incomingUsername"];
    [self setPrimitiveValue:value forKey:@"incomingUsername"];
    [self didChangeValueForKey:@"incomingUsername"];
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
    const char *serverName = [[self incomingServerName] UTF8String];
    const char *accountName = [[self incomingUsername] UTF8String];
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
                                                   itemRef //<#SecKeychainItemRef * itemRef#>
                                                   );
    if (err != noErr)
    {
        if (NSDebugEnabled) NSLog(@"Error with getting password (%d)", err);
    }
    else
    {
        NSData *data = [NSData dataWithBytesNoCopy:passwordData length:passwordLength];
        result = [NSString stringWithData:data encoding:NSUTF8StringEncoding]; 
        
        err = SecKeychainItemFreeContent(
                                         NULL,           //No attribute data to release
                                         passwordData    //Release data buffer allocated 
                                         );
        
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
    const char *accountName = [[self incomingUsername] UTF8String];
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
    if (itemRef) CFRelease(itemRef);
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
    [self setPrimitiveValue:[NSNumber numberWithInt: value]
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

- (int)outgoingServerType 
{
    NSNumber *tmpValue;
    
    [self willAccessValueForKey:@"outgoingServerType"];
    tmpValue = [self primitiveValueForKey:@"outgoingServerType"];
    [self didAccessValueForKey:@"outgoingServerType"];
    
    return (tmpValue != nil) ? [tmpValue intValue] : 0;
}

- (void)setOutgoingServerType:(int)value 
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
    NSString * tmpValue;
    
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
    [self setPrimitiveValue:[NSNumber numberWithInt:value]
                     forKey:@"outgoingServerPort"];
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
    [self setPrimitiveValue:[NSNumber numberWithInt: value]
                     forKey:@"outgoingAuthenticationMethod"];
    [self didChangeValueForKey:@"outgoingAuthenticationMethod"];
	
    [self willChangeValueForKey:@"outgoingUsernameNeeded"];
    [self didChangeValueForKey:@"outgoingUsernameNeeded"];
}

- (NSString *)outgoingUsername 
{
    NSString *tmpValue;
    
    [self willAccessValueForKey:@"outgoingUsername"];
    tmpValue = [self primitiveValueForKey:@"outgoingUsername"];
    [self didAccessValueForKey:@"outgoingUsername"];
    
    return tmpValue;
}

- (void)setOutgoingUsername:(NSString *)value 
{
    [self willChangeValueForKey:@"outgoingUsername"];
    [self setPrimitiveValue:value forKey:@"outgoingUsername"];
    [self didChangeValueForKey:@"outgoingUsername"];
}

- (BOOL)outgoingUsernameNeeded
{
    return [self outgoingAuthenticationMethod] == SMTPAuthentication;
}

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
    [self setPrimitiveValue:[NSNumber numberWithBool: value]
                     forKey:@"allowExpiredSSLCertificates"];
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
    [self setPrimitiveValue:[NSNumber numberWithBool:value]
                     forKey:@"allowAnyRootSSLCertificate"];
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
    [self setPrimitiveValue:[NSNumber numberWithBool: value]
                     forKey:@"verifySSLCertificateChain"];
    [self didChangeValueForKey:@"verifySSLCertificateChain"];
}

- (BOOL)isPOPAccount
{
    int type = [self incomingServerType];
    
    return (type == POP3) || (type == POP3S);
}

@end
