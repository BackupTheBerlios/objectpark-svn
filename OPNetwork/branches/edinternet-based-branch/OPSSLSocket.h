//
//  $Id: OPSSLSocket.h,v 1.2 2005/03/25 22:39:05 theisen Exp $
//  OPMessageServices
//
//  Created by joerg on Mon Sep 17 2001.
//  Copyright (c) 2001 Jšrg Westheide. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OPTCPSocket.h"
#include <Security/Security.h>

/*"Theses constants are the keys for the userinfo dictionary of the OPSSLExceptions."*/
#define OPEErrorCode       @"OPEErrorCode"
#define OPEFailedCall      @"OPEFailedCall"
#define OPECallingMethod   @"OPECallingMethod"
#define OPECallingObject   @"OPECallingObject"

@interface OPSSLSocket : OPTCPSocket
    {
    @private
    BOOL          _encrypted;         /*"These variables are private (and therefore not documented)."*/
    SSLContextRef _context;           /*""*/
    }

/*"Protcol and cipher names"*/
+ (NSString*) cipherToString:(SSLCipherSuite)cipher;
+ (NSString*) protocolToString:(SSLProtocol)protocol;

/*"Init methods"*/
- (OPSSLSocket*) init;
- (OPSSLSocket*) initAsServer;
- (OPSSLSocket*) initWithFileHandle:(NSFileHandle *)aFileHandle;
- (OPSSLSocket*) initAsServerWithFileHandle:(NSFileHandle *)aFileHandle;

/*"Reading data"*/
- (NSData*) availableData;

//- (NSData*) readDataToEndOfFile;
- (NSData*) readDataOfLength:(unsigned int)length;

/*"Writing data"*/
- (void) writeData:(NSData*)data;
/*
- (unsigned long long) offsetInFile;
- (unsigned long long) seekToEndOfFile;
- (void) seekToFileOffset:(unsigned long long)offset;

- (void) truncateFileAtOffset:(unsigned long long)offset;
- (void) synchronizeFile;
*/

/*"Maintaining connection"*/
- (void) closeFile;

/*"Maintaining encryption"*/
- (void) negotiateEncryption;
- (void) shutdownEncryption;
- (BOOL) isEncrypted;

/*"Certificate verification parameters"*/
- (BOOL) allowsAnyRootCertificate;
- (void) setAllowsAnyRootCertificate:(BOOL)allowed;
- (BOOL) allowsExpiredCertificates;
- (void) setAllowsExpiredCertificates:(BOOL)allowed;

/*"Inquireing session parameters"*/
- (SSLProtocol)    negotiatedProtocol;
- (SSLCipherSuite) negotiatedCipher;

@end

@interface NSFileHandle (OPSSLSocket)

- (BOOL) isEncrypted; // Superclass returns NO by default.

@end
