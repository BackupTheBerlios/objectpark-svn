//
//  GIAccount.h
//  Gina
//
//  Created by Dirk Theisen on 18.10.05.
//  Revised by Axel Katerbau on 25.12.07.
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
	NSString *name;
	
	NSString *incomingUsername;
	NSString *outgoingUsername;
	int retrieveMessageInterval; // in minutes

	unsigned leaveOnServerDuration; // in days
	int outgoingAuthenticationMethod;
	unsigned incomingServerPort;
	unsigned outgoingServerPort;
	NSString *outgoingServerName;
	unsigned outgoingServerType;
	NSString *incomingServerName;
	unsigned incomingServerType;
	unsigned incomingAuthenticationMethod;
	
	BOOL allowAnyRootSSLCertificate;
	BOOL allowExpiredSSLCertificates;
	BOOL verifySSLCertificateChain;
	
	OPFaultingArray *profiles;
}

/*" Incoming Properties "*/
@property(readwrite, copy) NSString *incomingUsername;
@property(readwrite, copy) NSString *incomingServerName;
@property(readwrite) int incomingAuthenticationMethod;
@property(readwrite) int incomingServerType;
@property(readwrite) unsigned incomingServerPort;
@property(readonly) int incomingServerDefaultPort;
@property(readwrite, copy) NSString *incomingPassword;
@property(readwrite) int retrieveMessageInterval;
@property(readwrite) int leaveOnServerDuration;
- (BOOL)isPOPAccount;

/*" Outgoing Properties "*/
@property(readwrite, copy) NSString *outgoingUsername;
@property(readwrite, copy) NSString *outgoingServerName;
@property(readwrite) int outgoingServerType;
@property(readwrite) unsigned outgoingServerPort;
@property(readonly) int outgoingServerDefaultPort;
@property(readwrite) int outgoingAuthenticationMethod;
@property(readwrite, copy) NSString *outgoingPassword;
@property(readonly) BOOL outgoingUsernameNeeded;

/*" SSL Properties "*/
@property(readwrite) BOOL allowExpiredSSLCertificates;
@property(readwrite) BOOL allowAnyRootSSLCertificate;
@property(readwrite) BOOL verifySSLCertificateChain;

/*" Other Properties "*/
@property(readwrite) BOOL isEnabled;
@property(readwrite, copy) NSString *name;

/*" Designated initializer "*/
- (id)init;

/*" Class methods "*/
+ (int)defaultPortForIncomingServerType:(int)serverType;
+ (int)defaultPortForOutgoingServerType:(int)serverType;

@end

/*" Sending and Retrieving "*/
@interface GIAccount (SendingAndReceiving)

+ (void)resetAccountRetrieveAndSendTimers;
+ (BOOL)anyMessagesRipeForSendingAtTimeIntervalSinceNow:(NSTimeInterval)interval;
- (void)sendMessagesRipeForSendingAtTimeIntervalSinceNow:(NSTimeInterval)interval;
- (void)send;
- (void)receive;

@end
