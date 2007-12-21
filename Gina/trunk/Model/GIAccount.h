//
//  GIAccount.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 18.10.05.
//  Copyright 2005 Objectpark Group. All rights reserved.
//

#import <OPPersistentObject.h>

@class OPFaultingArray;

enum IncomingServerTypes
{
    POP3, POP3S, NNTP, NNTPS
};

enum OutgoingServerTypes
{
    SMTP, SMTPS, SMTPTLS
};

enum IncomingAuthenticationMethods
{
    APOPOptional, APOPRequired, PlainText
};

enum OutgoingAuthenticationMethods
{
    SMTPAfterPOP, None, SMTPAuthentication
};

enum RetrieveMessageIntervall
{
    Manually = 0, EveryMinute = 1, Every5Minutes = 5, Every10Minutes = 10, Every15Minutes = 15, Every20Minutes = 20, Every30Minutes = 30, EveryHour = 60
};

enum LeaveOnServerDuration
{
    Never = -1, Forever = 0, FourWeeks = 28, OneWeek = 7, ThreeDays = 3
};

@interface GIAccount : OPPersistentObject 
{
	BOOL isEnabled;
	NSString* name;
	
	NSString* incomingUsername;
	NSString* outgoingUsername;
	NSNumber* retrieveMessageInterval;

	unsigned leaveOnServerDuration;
	int outgoingAuthenticationMethod;
	unsigned incomingServerPort;
	NSString* outgoingServerName;
	unsigned outgoingServerType;
	NSString* incomingServerName;
	unsigned incomingServerType;
	unsigned incomingAuthenticationMethod;
	
	BOOL allowAnyRootSSLCertificate;
	BOOL allowExpiredSSLCertificates;
	BOOL verifySSLCertificateChain;
	
	OPFaultingArray* profiles;
}


@property(readwrite, copy) NSString* incomingUsername;
@property(readwrite, copy) NSString* incomingServerName;

@property(readwrite, copy) NSString* outgoingUsername;
@property(readwrite, copy) NSString* outgoingServerName;

/*" Designated initializer "*/
- (id)init;

/*" Class methods "*/
+ (int)defaultPortForIncomingServerType:(int)serverType;
+ (int)defaultPortForOutgoingServerType:(int)serverType;

/*" Accessors "*/


- (int)incomingServerType;
- (void)setIncomingServerType:(int)aType;

- (NSString *)incomingServerName;
- (void)setIncomingServerName:(NSString *)aName;

- (int)incomingServerPort;
- (void)setIncomingServerPort:(int)aPort;

- (int)incomingServerDefaultPort;

- (int)incomingAuthenticationMethod;
- (void)setIncomingAuthenticationMethod:(int)aMethod;

/*
- (NSString *)incomingUsername;
- (void)setIncomingUsername:(NSString *)aName;
*/

- (NSString *)incomingPassword;
- (void)setIncomingPassword:(NSString *)aPassword;

- (int)retrieveMessageInterval;
- (void) setRetrieveMessageInterval:(int)minutes;

- (int)leaveOnServerDuration;
- (void)setLeaveOnServerDuration:(int)days;

- (int)outgoingServerType;
- (void)setOutgoingServerType:(int)aType;

- (BOOL)isPOPAccount;

- (NSString *)outgoingServerName;
- (void)setOutgoingServerName:(NSString *)aName;

- (int)outgoingServerPort;
- (void)setOutgoingServerPort:(int)aPort;

- (int)outgoingServerDefaultPort;

- (int)outgoingAuthenticationMethod;
- (void)setOutgoingAuthenticationMethod:(int)aMethod;

//- (NSString* )outgoingUsername;
//- (void)setOutgoingUsername:(NSString* )aName;

- (NSString *)outgoingPassword;
- (void)setOutgoingPassword:(NSString *)aPassword;

- (BOOL)outgoingUsernameNeeded;

/*
- (BOOL)allowExpiredSSLCertificates;
- (BOOL)allowAnyRootSSLCertificate;
- (BOOL)verifySSLCertificateChain;
- (void)setVerifySSLCertificateChain:(BOOL)value;
*/
@end

/*" Sending and Retrieving "*/
@interface GIAccount (SendingAndReceiving)

+ (void)resetAccountRetrieveAndSendTimers;
+ (BOOL)anyMessagesRipeForSendingAtTimeIntervalSinceNow:(NSTimeInterval)interval;
- (void)sendMessagesRipeForSendingAtTimeIntervalSinceNow:(NSTimeInterval)interval;
- (void)send;
- (void)receive;

@end
