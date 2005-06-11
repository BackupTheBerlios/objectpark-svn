//
//  $Id: OPSSLSocket.m,v 1.2 2005/03/25 22:39:05 theisen Exp $
//
//  Created by joerg on Mon Sep 17 2001.
//  Copyright (c) 2001 Jšrg Westheide. All rights reserved.
//

//#import "MPWDebug.h"

#import "OPSSLSocket.h"
#include <sys/socket.h>
#include <openssl/rand.h>
//#import "OPDebug.h"

#define OPDebugLog(a,b,format) NSLog(format)
#define OPDebugLog1(a,b,format,param) NSLog(format, param)
#define OPDebugLog2(a,b,format,param1,param2) NSLog(format, param1,param2)

#define OPStringForErrorCode(code) (strerror(code))


//#import "NSString+OPOSErrors.h"

#include <Security/Security.h>
#include <unistd.h>


#define OPSSLException  @"SSLException"

@interface OPSSLSocket(PrivateAPI)
- (OPSSLSocket*)_initAsServer:(BOOL)asServer;
- (OPSSLSocket*)_initAsServer:(BOOL)asServer withFileHandle:(NSFileHandle *)aFileHandle;
- (OPSSLSocket*)_initSSLAsServer:(BOOL)asServer;
- (NSException*)_createOPSSLExceptionWithReason:(NSString*)reason errorCode:(OSStatus)errorCode failedCall:(NSString*)failedCall callingMethod:(SEL)callingMethod callingObject:(id)callingObject;
@end


@implementation OPSSLSocket
/*"This class provides sockets with integrated SSL functionality.

If an error occurs an exception of type OPSSLException is thrown.
The reason contains a short description while the userinfo dictionary contains the following key value pairs:

- OPEErrorCode:       A NSNumber containing the error code returned by a function call to the security framework

- OPEFailedCall:      A NSString with the name of the function which returned the error code

- OPECallingMethod:   A NSString with the selector of the method which made the failing function call

- OPECallingObject:   The object on which the above method was called
    "*/


/*"This method gives you a string naming the protocol"*/
+(NSString*) protocolToString:(SSLProtocol) protocol
{
    switch (protocol)
    {
        case kSSLProtocolUnknown: return @"no protocol";
        case kSSLProtocol2:       return @"SSLv2";
        case kSSLProtocol3:       return @"SSLv3";
        case kSSLProtocol3Only:   return @"SSLv3 only";
        case kTLSProtocol1:       return @"TLS";
        case kTLSProtocol1Only:   return @"TLS only";
        default:                  return [NSString stringWithFormat:@"unknown protocol with number %d", protocol];
    }
}



/*"This method gives you a string naming the cipher"*/
+(NSString*) cipherToString:(SSLCipherSuite) cipher
{
    switch (cipher)
    {
        case SSL_NULL_WITH_NULL_NULL:                 return @"SSL_NULL_WITH_NULL_NULL";
        case SSL_RSA_WITH_NULL_MD5:                   return @"SSL_RSA_WITH_NULL_MD5";
        case SSL_RSA_WITH_NULL_SHA:                   return @"SSL_RSA_WITH_NULL_SHA";
        case SSL_RSA_EXPORT_WITH_RC4_40_MD5:          return @"SSL_RSA_EXPORT_WITH_RC4_40_MD5";
        case SSL_RSA_WITH_RC4_128_MD5:                return @"SSL_RSA_WITH_RC4_128_MD5";
        case SSL_RSA_WITH_RC4_128_SHA:                return @"SSL_RSA_WITH_RC4_128_SHA";
        case SSL_RSA_EXPORT_WITH_RC2_CBC_40_MD5:      return @"SSL_RSA_EXPORT_WITH_RC2_CBC_40_MD5";
        case SSL_RSA_WITH_IDEA_CBC_SHA:               return @"SSL_RSA_WITH_IDEA_CBC_SHA";
        case SSL_RSA_EXPORT_WITH_DES40_CBC_SHA:       return @"SSL_RSA_EXPORT_WITH_DES40_CBC_SHA";
        case SSL_RSA_WITH_DES_CBC_SHA:                return @"SSL_RSA_WITH_DES_CBC_SHA";
        case SSL_RSA_WITH_3DES_EDE_CBC_SHA:           return @"SSL_RSA_WITH_3DES_EDE_CBC_SHA";
        case SSL_DH_DSS_EXPORT_WITH_DES40_CBC_SHA:    return @"SSL_DH_DSS_EXPORT_WITH_DES40_CBC_SHA";
        case SSL_DH_DSS_WITH_DES_CBC_SHA:             return @"SSL_DH_DSS_WITH_DES_CBC_SHA";
        case SSL_DH_DSS_WITH_3DES_EDE_CBC_SHA:        return @"SSL_DH_DSS_WITH_3DES_EDE_CBC_SHA";
        case SSL_DH_RSA_EXPORT_WITH_DES40_CBC_SHA:    return @"SSL_DH_RSA_EXPORT_WITH_DES40_CBC_SHA";
        case SSL_DH_RSA_WITH_DES_CBC_SHA:             return @"SSL_DH_RSA_WITH_DES_CBC_SHA";
        case SSL_DH_RSA_WITH_3DES_EDE_CBC_SHA:        return @"SSL_DH_RSA_WITH_3DES_EDE_CBC_SHA";
        case SSL_DHE_DSS_EXPORT_WITH_DES40_CBC_SHA:   return @"SSL_DHE_DSS_EXPORT_WITH_DES40_CBC_SHA";
        case SSL_DHE_DSS_WITH_DES_CBC_SHA:            return @"SSL_DHE_DSS_WITH_DES_CBC_SHA";
        case SSL_DHE_DSS_WITH_3DES_EDE_CBC_SHA:       return @"SSL_DHE_DSS_WITH_3DES_EDE_CBC_SHA";
        case SSL_DHE_RSA_EXPORT_WITH_DES40_CBC_SHA:   return @"SSL_DHE_RSA_EXPORT_WITH_DES40_CBC_SHA";
        case SSL_DHE_RSA_WITH_DES_CBC_SHA:            return @"SSL_DHE_RSA_WITH_DES_CBC_SHA";
        case SSL_DHE_RSA_WITH_3DES_EDE_CBC_SHA:       return @"SSL_DHE_RSA_WITH_3DES_EDE_CBC_SHA";
        case SSL_DH_anon_EXPORT_WITH_RC4_40_MD5:      return @"SSL_DH_anon_EXPORT_WITH_RC4_40_MD5";
        case SSL_DH_anon_WITH_RC4_128_MD5:            return @"SSL_DH_anon_WITH_RC4_128_MD5";
        case SSL_DH_anon_EXPORT_WITH_DES40_CBC_SHA:   return @"SSL_DH_anon_EXPORT_WITH_DES40_CBC_SHA";
        case SSL_DH_anon_WITH_DES_CBC_SHA:            return @"SSL_DH_anon_WITH_DES_CBC_SHA";
        case SSL_DH_anon_WITH_3DES_EDE_CBC_SHA:       return @"SSL_DH_anon_WITH_3DES_EDE_CBC_SHA";
        case SSL_FORTEZZA_DMS_WITH_NULL_SHA:          return @"SSL_FORTEZZA_DMS_WITH_NULL_SHA";
        case SSL_FORTEZZA_DMS_WITH_FORTEZZA_CBC_SHA:  return @"SSL_FORTEZZA_DMS_WITH_FORTEZZA_CBC_SHA";
            
            // These ciphers are not in RFC 2246, they are from [SSL and TLS, Eric Rescorla, 2001]
        case 0x0062:                                  return @"SSL_RSA_EXPORT1024_WITH_DES_CBC_SHA";
        case 0x0063:                                  return @"SSL_DHE_DSS_EXPORT1024_WITH_DES_CBC_SHA";
        case 0x0064:                                  return @"SSL_RSA_EXPORT1024_WITH_RC4_56_SHA";
        case 0x0065:                                  return @"SSL_DHE_DSS_EXPORT1024_WITH_RC4_56_SHA";
        case 0x0066:                                  return @"SSL_DHE_DSS_WITH_RC4_128_SHA";
            
            // SSL 2 ciphers that are not defined for SSL 3
        case SSL_RSA_WITH_RC2_CBC_MD5:                return @"SSL_RSA_WITH_RC2_CBC_MD5";
        case SSL_RSA_WITH_IDEA_CBC_MD5:               return @"SSL_RSA_WITH_IDEA_CBC_MD5";
        case SSL_RSA_WITH_DES_CBC_MD5:                return @"SSL_RSA_WITH_DES_CBC_MD5";
        case SSL_RSA_WITH_3DES_EDE_CBC_MD5:           return @"SSL_RSA_WITH_3DES_EDE_CBC_MD5";
            
        case SSL_NO_SUCH_CIPHERSUITE:                 return @"no such ciphersuite";
            
        default:                                      return [NSString stringWithFormat:@"unknown cipher with number %X", cipher];
    }
}


/*"private method which creates an OPSSLException."*/
- (NSException*) _createOPSSLExceptionWithReason:(NSString*)reason errorCode:(OSStatus)errorCode failedCall:(NSString*)failedCall callingMethod:(SEL)callingMethod callingObject:(id)callingObject
{
    //OPDebugLog5(SSLDEBUG, OPINFO, @"creating SSL exception with reason %@, error code %d from call %@ in method %@ called for object %@", reason, errorCode, failedCall, NSStringFromSelector(callingMethod), callingObject);
    return [NSException exceptionWithName:OPSSLException
                                   reason:reason
                                 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithLong:errorCode], OPEErrorCode,                                                                                     failedCall, OPEFailedCall,
                                     NSStringFromSelector(callingMethod), OPECallingMethod,
                                     callingObject, OPECallingObject,
                                     nil, nil]];
}


/*"Signal handler for catching SIGPIPE signals."*/
static void sigPipeHandler(int x)
{
    OPDebugLog1(SSLDEBUG, OPERROR, @"Signal SIGPIPE (%d) catched!", x);
}

OSStatus ssl_read(SSLConnectionRef connection, void *rawdata, size_t *rawdatalength);
OSStatus ssl_write(SSLConnectionRef connection, const void *rawdata, size_t *rawdatalength);




/*"Standard init method for clients"*/
- (OPSSLSocket*)init
{
    return [self _initAsServer:NO];
}

/*"Standard init method for servers"*/
- (OPSSLSocket*)initAsServer
{
    return [self _initAsServer:YES];
}

- (OPSSLSocket*)_initAsServer:(BOOL)asServer
{
    if (self = [super init])
        self = [self _initSSLAsServer:asServer];
    
    return self;
}


/*"Init method for clients that want to provide their own NSFileHandle"*/
- (OPSSLSocket*)initWithFileHandle:(NSFileHandle *)aFileHandle
{
    return [self _initAsServer:NO withFileHandle:aFileHandle];
}

/*"Init method for servers that want to provide their own NSFileHandle"*/
- (OPSSLSocket*)initAsServerWithFileHandle:(NSFileHandle *)aFileHandle
{
    return [self _initAsServer:YES withFileHandle:aFileHandle];
}

- (OPSSLSocket*)_initAsServer:(BOOL)asServer withFileHandle:(NSFileHandle *)aFileHandle
{
    if (self = [super initWithFileHandle:aFileHandle])
        self = [self _initSSLAsServer:asServer];
    
    return self;
}


- (OPSSLSocket*)_initSSLAsServer:(BOOL)asServer
{
    OSStatus err;
    
    _encrypted = NO;
    
    err = SSLNewContext(asServer, &_context);
    if (!err)
    {
        err = SSLSetConnection(_context, self/*(void*)[self fileDescriptor]*/);
        if (!err)
        {
            err = SSLSetIOFuncs(_context, ssl_read, ssl_write);
            if (!err)
            {
                signal(SIGPIPE, sigPipeHandler);
                return self;
            }
            
            OPDebugLog1(SSLDEBUG, OPERROR, @"SSLSetIOFuncs() failed with error %d", err);
        }
        else
            OPDebugLog1(SSLDEBUG, OPERROR, @"SSLSetConnection() failed with error %d", err);
        
        SSLDisposeContext(_context);
    }
    else
        OPDebugLog1(SSLDEBUG, OPERROR, @"SSLNewContext() failed with error %d", err);
    
    self = nil;
    return self;
}


// We don't need these
//- (OPSSLSocket*) init;
//- (OPSSLSocket*) initWithFileDescriptor:(int)fd;
//- (OPSSLSocket*) initWithFileDescriptor:(int)fd closeOnDealloc:(BOOL)closeopt;
//- (OPSSLSocket*) initWithFileHandle:(NSFileHandle *)aFileHandle;

/*"Reads all available data from the socket."*/
- (NSData*) availableData
{
    OSStatus err;
    size_t bufSize;
    
    if (!_encrypted)
        return [super availableData];
    
    err = SSLGetBufferedReadSize(_context, &bufSize);
    if (err)
    {
        OPDebugLog1(SSLDEBUG, OPERROR, @"SSLGetBufferedReadSize(): %s", OPStringForErrorCode(err));
        [[self _createOPSSLExceptionWithReason: [NSString stringWithFormat: @"SSLGetBufferedReadSize(): %s", OPStringForErrorCode(err)]
                                     errorCode: err
                                    failedCall: @"SSLGetBufferedReadSize()"
                                 callingMethod: _cmd
                                 callingObject: self]
            raise];
    }
    
    if (!bufSize)
        bufSize = 1;
    
    return [self readDataOfLength:bufSize];
}


//- (NSData*) readDataToEndOfFile;

/*"Reads %length bytes from the socket.
This call is blocking so it returns less than %length bytes only if an error occured (i.e. the connection was closed)."*/
- (NSData*) readDataOfLength:(unsigned int)length
{
    OSStatus err;
    char rawData[16384];
    int bytesRead = 0;
    size_t bytesReadThisTime;
    NSMutableData* data;
    
    if (!_encrypted)
        return [super readDataOfLength:length];
    
    data = [NSMutableData dataWithCapacity:length];
    
    do
    {
        bytesReadThisTime = 0;
        err = SSLRead(_context, &rawData+bytesRead, /*length-bytesRead > 16384 ? 16384 :*/ length-bytesRead, &bytesReadThisTime);
        [data appendBytes:&rawData length:bytesReadThisTime];
        bytesRead += bytesReadThisTime;
        if (err)
        {
            OPDebugLog1(SSLDEBUG, OPERROR, @"SSLRead(): %s", OPStringForErrorCode(err));
            
            if (err == errSSLWouldBlock)
                continue;
            
            [[self _createOPSSLExceptionWithReason:[NSString stringWithFormat:@"SSLRead(): %s", OPStringForErrorCode(err)]
                                         errorCode:err
                                        failedCall:@"SSLRead()"
                                     callingMethod:_cmd
                                     callingObject:self]
                raise];
        }
    }
    while (bytesRead < length);
    
    return data;
}


/*"This methods writes %data to the socket."*/
- (void) writeData:(NSData*)data
{
    OSStatus err;
    size_t bytesWritten = 0;
    size_t bytesWrittenThisTime;
    size_t length = [data length];
    const void *rawData;
    
    if (!_encrypted)
    {
        [super writeData:data];
        return;
    }
    
    rawData = [data bytes];
    
    do
    {
        bytesWrittenThisTime = 0;
        err = SSLWrite(_context, rawData+bytesWritten, length-bytesWritten, &bytesWrittenThisTime);
        bytesWritten += bytesWrittenThisTime;
        if (err)
        {
            OPDebugLog1(SSLDEBUG, OPERROR, @"SSLWrite(): %@", OPStringForErrorCode(err));
            
            if (err == errSSLWouldBlock)
                continue;
            
            [[self _createOPSSLExceptionWithReason:[NSString stringWithFormat:@"SSLWrite(): %@", OPStringForErrorCode(err)]
                                         errorCode:err
                                        failedCall:@"SSLWrite()"
                                     callingMethod:_cmd
                                     callingObject:self]
                raise];
        }
    }
    while (bytesWritten < length);
}

/*
 - (unsigned long long) offsetInFile;
 - (unsigned long long) seekToEndOfFile;
 - (void) seekToFileOffset:(unsigned long long)offset;
 
 - (void) truncateFileAtOffset:(unsigned long long)offset;
 - (void) synchronizeFile;
 */


/*"Closes the connection. If SSL is active SSL is shut down first."*/
- (void) closeFile
{
    OSStatus err;
    
    OPDebugLog(SSLDEBUG, OPINFO, @"closing secure socket");
    
    if ([self isEncrypted])
        [self shutdownEncryption];
    
    err = SSLDisposeContext(_context);
    if (err)
    {
        OPDebugLog1(SSLDEBUG, OPERROR, @"SSLDisposeContext(): %@", OPStringForErrorCode(err));
        [[self _createOPSSLExceptionWithReason:[NSString stringWithFormat:@"SSLDisposeContext(): %@", OPStringForErrorCode(err)]
                                     errorCode:err
                                    failedCall:@"SSLDisposeContext()"
                                 callingMethod:_cmd
                                 callingObject:self]
            raise];
    }
    
    [super closeFile];
}


/*"Starts the SSL encryption on the socket.
The TCP connection on the socket has to be established before calling this method."*/
- (void) negotiateEncryption
{
    OSStatus err;
    
    OPDebugLog(SSLDEBUG, OPALL, @"negotiating encryption...");
    
    err = SSLHandshake(_context);
    if (err < 0)
    {
        OPDebugLog1(SSLDEBUG, OPERROR, @"SSLHandshake(): %@", OPStringForErrorCode(err));
        [[self _createOPSSLExceptionWithReason:[NSString stringWithFormat:@"SSLHandshake(): %@", OPStringForErrorCode(err)]
                                     errorCode:err
                                    failedCall:@"SSLHandshake()"
                                 callingMethod:_cmd
                                 callingObject:self]
            raise];
    }
    
    _encrypted = YES;
    
    OPDebugLog(SSLDEBUG, OPINFO, @"negotiating encryption successful");
    NS_DURING
        OPDebugLog2(SSLDEBUG, OPINFO, @"negotiated protocol %@ with cipher: %@", [OPSSLSocket protocolToString:[self negotiatedProtocol]], [OPSSLSocket cipherToString:[self negotiatedCipher]]);
    NS_HANDLER
        NS_ENDHANDLER
}


/*"Shuts down the SSL encryption."*/
- (void) shutdownEncryption
{
    OSStatus err;
    
    OPDebugLog(SSLDEBUG, OPALL, @"shutting down encryption");
    
    err = SSLClose(_context);
    if (err)
    {
        OPDebugLog1(SSLDEBUG, OPERROR, @"SSLClose(): %@", OPStringForErrorCode(err));
        [[self _createOPSSLExceptionWithReason:[NSString stringWithFormat:@"SSLClose(): %@", OPStringForErrorCode(err)]
                                     errorCode:err
                                    failedCall:@"SSLClose()"
                                 callingMethod:_cmd
                                 callingObject:self]
            raise];
    }
    
    _encrypted = NO;
}


/*"This method reports whether SSL encryption is active (YES) or not (NO)."*/
- (BOOL) isEncrypted
{
    SSLSessionState state;
    OSStatus err;
    
    OPDebugLog(SSLDEBUG, OPALL, @"inquireing encryption state");
    
    err = SSLGetSessionState(_context, &state);
    if (err)
    {
        OPDebugLog1(SSLDEBUG, OPERROR, @"SSLGetSessionState(): %@", OPStringForErrorCode(err));
        [[self _createOPSSLExceptionWithReason:[NSString stringWithFormat:@"SSLGetSessionState(): %@", OPStringForErrorCode(err)]
                                     errorCode:err
                                    failedCall:@"SSLGetSessionState()"
                                 callingMethod:_cmd
                                 callingObject:self]
            raise];
    }
    
    return (state == kSSLConnected);
}


/*
 * Certificate verification parameters
 */

/*"This method inquires if any root certificate is allowed."*/
- (BOOL) allowsAnyRootCertificate
{
    BOOL allowed;
    OSStatus err = SSLGetAllowsAnyRoot(_context, &allowed);
    if (err)
    {
        OPDebugLog1(SSLDEBUG, OPERROR, @"SSLGetAllowsAnyRoot(): %@", OPStringForErrorCode(err));
        [[self _createOPSSLExceptionWithReason:[NSString stringWithFormat:@"SSLGetAllowsAnyRoot(): %@", OPStringForErrorCode(err)]
                                     errorCode:err
                                    failedCall:@"SSLGetAllowsAnyRoot()"
                                 callingMethod:_cmd
                                 callingObject:self]
            raise];
    }
    
    return allowed;
}


/*"Sets whether any root certificate is allowed (YES) or not (NO).
Setting YES means that an important part of the certificate verification is not done.
While it is loss of security it enables operation with servers that have 
certificates that are not signed by the root CAs supported by the system 
(mostly self signed certificates)."*/
- (void) setAllowsAnyRootCertificate:(BOOL)allowed
{
    OSStatus err = SSLSetAllowsAnyRoot(_context, allowed);
    if (err)
    {
        OPDebugLog1(SSLDEBUG, OPERROR, @"SSLSetAllowsAnyRoot(): %@", OPStringForErrorCode(err));
        [[self _createOPSSLExceptionWithReason:[NSString stringWithFormat:@"SSLSetAllowsAnyRoot(): %@", OPStringForErrorCode(err)]
                                     errorCode:err
                                    failedCall:@"SSLSetAllowsAnyRoot()"
                                 callingMethod:_cmd
                                 callingObject:self]
            raise];
    }
}


/*"This method inquires if expired certificates are allowed."*/
- (BOOL) allowsExpiredCertificates
{
    BOOL allowed;
    OSStatus err = SSLGetAllowsExpiredCerts(_context, &allowed);
    if (err)
    {
        OPDebugLog1(SSLDEBUG, OPERROR, @"SSLGetAllowsExpiredCerts(): %@", OPStringForErrorCode(err));
        [[self _createOPSSLExceptionWithReason:[NSString stringWithFormat:@"SSLGetAllowsExpiredCerts(): %@", OPStringForErrorCode(err)]
                                     errorCode:err
                                    failedCall:@"SSLGetAllowsExpiredCerts()"
                                 callingMethod:_cmd
                                 callingObject:self]
            raise];
    }
    
    return allowed;
}


/*"Sets whether expired certificates are allowed (YES) or not (NO).
Setting YES means that a part of the certificate verification is not done."*/
- (void) setAllowsExpiredCertificates:(BOOL)allowed
{
    OSStatus err = SSLSetAllowsExpiredCerts(_context, allowed);
    if (err)
    {
        OPDebugLog1(SSLDEBUG, OPERROR, @"SSLSetAllowsExpiredCerts(): %@", OPStringForErrorCode(err));
        [[self _createOPSSLExceptionWithReason:[NSString stringWithFormat:@"SSLSetAllowsExpiredCerts(): %@", OPStringForErrorCode(err)]
                                     errorCode:err
                                    failedCall:@"SSLSetAllowsExpiredCerts()"
                                 callingMethod:_cmd
                                 callingObject:self]
            raise];
    }
}


/*
 * Inquireing session parameters
 */

/*"Returns the protocol currently used by the connection."*/
- (SSLProtocol) negotiatedProtocol
{
    SSLProtocol protocol;
    OSStatus err = SSLGetNegotiatedProtocolVersion(_context, &protocol);
    if (err)
    {
        OPDebugLog1(SSLDEBUG, OPERROR, @"SSLGetNegotiatedProtocolVersion(): %@", OPStringForErrorCode(err));
        [[self _createOPSSLExceptionWithReason:[NSString stringWithFormat:@"SSLGetNegotiatedProtocolVersion(): %@", OPStringForErrorCode(err)]
                                     errorCode:err
                                    failedCall:@"SSLGetNegotiatedProtocolVersion()"
                                 callingMethod:_cmd
                                 callingObject:self]
            raise];
    }
    
    return protocol;
}


/*"Returns the cipher currently used by the connection."*/
- (SSLCipherSuite) negotiatedCipher
{
    SSLCipherSuite cipher;
    OSStatus err = SSLGetNegotiatedCipher(_context, &cipher);
    if (err)
    {
        OPDebugLog1(SSLDEBUG, OPERROR, @"SSLGetNegotiatedCipher(): %s", OPStringForErrorCode(err));
        [[self _createOPSSLExceptionWithReason: [NSString stringWithFormat:@"SSLGetNegotiatedCipher(): %@", OPStringForErrorCode(err)]
                                     errorCode: err
                                    failedCall: @"SSLGetNegotiatedCipher()"
                                 callingMethod: _cmd
                                 callingObject: self]
            raise];
    }
    
    return cipher;
}


/*
 * Callbacks for reading/writing data from/to the socket
 */

/*"This is the callback for reading data from the socket, called by the SecureTransport framework"*/
OSStatus ssl_read(SSLConnectionRef connection, void *rawdata, size_t *rawdatalength)
{
    UInt32     bytesToGo = *rawdatalength;
    UInt32     initLen = bytesToGo;
    UInt8     *currData = (UInt8 *)rawdata;
    int        sock = [(OPSSLSocket*)connection fileDescriptor];
    OSStatus   rtn = noErr;
    UInt32     bytesRead;
    int        rrtn;
    
    *rawdatalength = 0;
    
    while (1)
    {
        bytesRead = 0;
        rrtn = read(sock, currData, bytesToGo);
        
        if (rrtn <= 0)
        {
            /* this is guesswork... */
            int theErr = errno;
            
            OPDebugLog2(SSLDEBUG, OPINFO, @"SocketRead: read(%d) error %d\n", (int)bytesToGo, theErr);
            
            if((rrtn == 0) && (theErr == 0))
            {
                /* try fix for iSync */ 
                rtn = errSSLClosedGraceful;
                //rtn = errSSLClosedAbort;
            }
            else /* do the switch */
                switch(theErr)
                {
                    case ENOENT:     /* connection closed */
                        rtn = errSSLClosedGraceful; 
                        break;
                    case ECONNRESET: rtn = errSSLClosedAbort;
                        break;
                    case 0:          /* ??? */
                        rtn = errSSLWouldBlock;
                        break;
                    default:         //OPDebugLog2(SSLDEBUG, OPINFO, @"SocketRead: read(%d) error %d\n", (int)bytesToGo, theErr);
                        rtn = ioErr;
                        break;
                }
                    
                    break;
        }
        else
            bytesRead = rrtn;
        
        bytesToGo -= bytesRead;
        currData  += bytesRead;
        
        if(bytesToGo == 0)
        {
            /* filled buffer with incoming data, done */
            break;
        }
    }
    
    *rawdatalength = initLen - bytesToGo;
    
    return rtn;
}


/*"This is the callback for writing data to the socket, called by the SecureTransport framework"*/
OSStatus ssl_write(SSLConnectionRef connection, const void *rawdata, size_t *rawdatalength)
{
    UInt32       bytesSent = 0;
    int          sock = [(OPSSLSocket*)connection fileDescriptor];
    int          length;
    UInt32       dataLen = *rawdatalength;
    const UInt8 *dataPtr = (UInt8 *)rawdata;
    OSStatus     ortn;
    
    *rawdatalength = 0;
    
    do
    {
        length = write(sock, (char*)dataPtr + bytesSent, dataLen - bytesSent);
    }
    while ((length > 0) && ((bytesSent += length) < dataLen));
    
    if (length <= 0)
        if (errno == EAGAIN)
            ortn = errSSLWouldBlock;
        else
            ortn = ioErr;  // -36
    else
        ortn = noErr;
    
    *rawdatalength = bytesSent;
    return ortn;
}

@end

@implementation NSFileHandle (OPSSLSocket)

- (BOOL) isEncrypted
/* Superclass implementation returns NO by default. */
{
    return NO;
}

@end
