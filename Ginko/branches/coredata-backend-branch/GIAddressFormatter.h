/* 
     $Id: GIAddressFormatter.h,v 1.1 2004/12/13 13:20:41 mikesch Exp $

     Copyright (c) 2001, 2005 by Axel Katerbau. All rights reserved.

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
     at http://www.objectpark.org/Ginko.html
*/

#import <Foundation/Foundation.h>

@interface GIAddressFormatter : NSFormatter
{

}

+ (void)addToLRUMailAddresses:(NSString *)anAddressString;
+ (void)removeFromLRUMailAddresses:(NSString *)anAddressString;

@end
