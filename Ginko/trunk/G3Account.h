//
//  G3Account.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 25.02.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OPManagedObject.h"

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

@interface G3Account : OPManagedObject 
{
}

/*" Designated initializer "*/
- (id)init;

/*" Class methods "*/
+ (NSArray *)accounts;
+ (void)setAccounts:(NSArray *)someAccounts;
+ (int)defaultPortForIncomingServerType:(int)serverType;
+ (int)defaultPortForOutgoingServerType:(int)serverType;

/*" Accessors "*/
- (NSString *)name;
- (void)setName:(NSString *)aString;

- (BOOL)isEnabled;
- (void)setIsEnabled:(BOOL)aBool;

- (int)incomingServerType;
- (void)setIncomingServerType:(int)aType;

- (NSString *)incomingServerName;
- (void)setIncomingServerName:(NSString *)aName;

- (int)incomingServerPort;
- (void)setIncomingServerPort:(int)aPort;

- (int)incomingServerDefaultPort;

- (int)incomingAuthenticationMethod;
- (void)setIncomingAuthenticationMethod:(int)aMethod;

- (NSString *)incomingUsername;
- (void)setIncomingUsername:(NSString *)aName;

- (int)retrieveMessageInterval;
- (void)setRetrieveMessageInterval:(int)minutes;

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

- (NSString *)outgoingUsername;
- (void)setOutgoingUsername:(NSString *)aName;

- (BOOL)outgoingUsernameNeeded;

@end
