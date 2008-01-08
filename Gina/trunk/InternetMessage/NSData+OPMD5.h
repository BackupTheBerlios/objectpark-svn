/*
 $Id: NSData+OPMD5.h,v 1.1 2004/12/23 16:45:48 theisen Exp $

 Copyright (c) 2002 by Axel Katerbau. All rights reserved.

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

 Further information can be found on the project's web pages
 at http://www.objectpark.org/Gina.html
 */

#import <Foundation/Foundation.h>

typedef unsigned char md5_byte_t; /* 8-bit byte */
typedef unsigned int md5_word_t; /* 32-bit word */

/* Define the state of the MD5 Algorithm. */
typedef struct md5_state_s {
    md5_word_t count[2];	/* message length in bits, lsw first */
    md5_word_t abcd[4];		/* digest buffer */
    md5_byte_t buf[64];		/* accumulate block */
} md5_state_t;

#ifdef __cplusplus
extern "C" 
{
#endif
    
    /* Initialize the algorithm. */
#ifdef P1
    void md5_init(P1(md5_state_t *pms));
#else
    void md5_init(md5_state_t *pms);
#endif
    
    /* Append a string to the message. */
#ifdef P3
    void md5_append(P3(md5_state_t *pms, const md5_byte_t *data, int nbytes));
#else
    void md5_append(md5_state_t *pms, const md5_byte_t *data, int nbytes);
#endif
    
    /* Finish the message and return the digest. */
#ifdef P2
    void md5_finish(P2(md5_state_t *pms, md5_byte_t digest[16]));
#else
    void md5_finish(md5_state_t *pms, md5_byte_t digest[16]);
#endif
    

@interface NSData (OPMD5)

- (NSString*) md5HexString;
- (NSString*) md5Base64String;

@end
