/* 
     OPMessageConsumer.h created by axel on Sun 31-Dec-2000
     $Id: OPMessageConsumer.h,v 1.1 2005/03/19 19:48:09 mikesch Exp $

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

/*
 The formal OPMessageConsumer protocol can be adopted by classes that provide
 a service that consumes OPMessage objects. Consuming means that the OPMessage
 objects consumed by an object whose class adopts the OPMessageConsumer protocol
 won't be available from the same object in the future.
 This semantics is different from the semantics of OPMessageStore. You should not mix
 the two accidentally.
*/
@protocol OPMessageConsumer

/* Returns YES if the receiver will accept at least one OPMessage for consumption. NO otherwise.*/
- (BOOL)willAcceptMessage;

/* The receiver will consume 'message' if willing and able to (cf. -willAcceptMessage). Raises
     an exception if the 'message' will not be consumed. */
- (void)acceptMessage:(OPInternetMessage *)message;

@end

extern NSString *OPMessageConsumerMessageNotAcceptedException;