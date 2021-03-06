/* 
     OPSMTP.h created by axel on Sat 02-Jun-2001
     $Id: OPSMTP.h,v 1.1 2005/03/19 19:48:09 mikesch Exp $

     Copyright (c) 2001 by Axel Katerbau. All rights reserved.

     Permission to use, copy, modify and distribute this software and its documentation
     is hereby granted, provided that both the copyright notice and this permission
     notice appear in all copies of the software, derivative works or modified versions,
     and any portions thereof, and that both notices appear in supporting documentation,
     and that credit is given to Axel Katerbau in all documents and publicity
     pertaining to direct or indirect use of this code or its derivatives.

     THIS IS EXPERIMENTAL SOFTWARE AND IT IS KNOWN TO HAVE BUGS, SOME OF WHICH MAY HAVE
     SERIOUS CONSEQUENCES. THE COPYRIGHT HOLDER ALLOWS FREE USE OF THIS SOFTWARE IN ITS
     "AS IS" CONDITION. THE COPYRIGHT HOLDER DISCLAIMS ANY LIABILITY OF ANY KIND FOR ANY
     DAMAGES WHATSOEVER RESULTING DIRECTLY OR INDIRECTLY FROM THE USE OF THIS SOFTWARE
     OR OF ANY DERIVATIVE WORK.
*/

#import <Foundation/Foundation.h>
#import "OPInternetMessage.h"
#import "OPMessageConsumer.h"
#import <OPNetwork/OPStream+SSL.h>

typedef enum _OPSMTPState
{
    Disconnected,
    Connected,
    NonAuthenticated,
    Authenticated
} OPSMTPState;

// RFC 821 SMTP
@interface OPSMTP : NSObject <OPMessageConsumer>
{
    @private
    OPStream *stream;
    NSMutableDictionary *capabilities;
    NSString *username, *password;
    NSMutableArray *pendingResponses; // inspired by EDInternet's EDSMTPStream by Erik D�rnenburg
    @private id _delegate;			/*" Delegate "*/
    int state;
}

+ (id)SMTPWithUsername:(NSString *)aUsername password:(NSString *)aPassword stream:(OPStream *)aStream;
+ (id)SMTPWithStream:(OPStream *)aStream andDelegate:(id)anObject;

- (id)initWithUsername:(NSString *)aUsername password:(NSString *)aPassword stream:(OPStream *)aStream;
- (id)initWithStream:(OPStream *)aStream andDelegate:(id)anObject;

@end

@protocol OPSMTPDelegate

- (NSString *)usernameForSMTP:(OPSMTP *)aSMTP;
/*" Required. Returns the username for use with the given SMTP aSMTP.
    SMTP sends this method paired with %{-passwordForSMTP:}. "*/

- (NSString *)passwordForSMTP:(OPSMTP *)aSMTP;
/*" Required. Returns the password for use with the given SMTP aSMTP.
    SMTP sends this method paired with %{-usernameForSMTP:}."*/

- (BOOL)useSMTPS:(OPSMTP *)aSMTP;
/*" Optional. Default is NO. "*/

- (BOOL)allowAnyRootCertificateForSMTP:(OPSMTP *)aSMTP;
/*" Optional. Default is NO. "*/

- (BOOL)allowExpiredCertificatesForSMTP:(OPSMTP *)aSMTP;
/*" Optional. Default is NO. "*/

@end

extern NSString *OPSMTPException;
extern NSString *OPBrokenSMPTServerHint;