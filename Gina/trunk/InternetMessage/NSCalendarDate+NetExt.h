//---------------------------------------------------------------------------------------
//  NSCalendarDate+NetExt.h created by erik
//  @(#)$Id: NSCalendarDate+NetExt.h,v 1.1 2004/12/23 17:59:15 theisen Exp $
//
//  Copyright (c) 2002 by Axel Katerbau. All rights reserved.
//
//  Permission to use, copy, modify and distribute this software and its documentation
//  is hereby granted, provided that both the copyright notice and this permission
//  notice appear in all copies of the software, derivative works or modified versions,
//  and any portions thereof, and that both notices appear in supporting documentation,
//  and that credit is given to Axel Katerbau in all documents and publicity
//  pertaining to direct or indirect use of this code or its derivatives.
//
//  THIS IS EXPERIMENTAL SOFTWARE AND IT IS KNOWN TO HAVE BUGS, SOME OF WHICH MAY HAVE
//  SERIOUS CONSEQUENCES. THE COPYRIGHT HOLDER ALLOWS FREE USE OF THIS SOFTWARE IN ITS
//  "AS IS" CONDITION. THE COPYRIGHT HOLDER DISCLAIMS ANY LIABILITY OF ANY KIND FOR ANY
//  DAMAGES WHATSOEVER RESULTING DIRECTLY OR INDIRECTLY FROM THE USE OF THIS SOFTWARE
//  OR OF ANY DERIVATIVE WORK.
//---------------------------------------------------------------------------------------


#ifndef	__NSCalendarDate_NetExt_h_INCLUDE
#define	__NSCalendarDate_NetExt_h_INCLUDE


@interface NSCalendarDate(EDNetExt)

+ (id)dateWithMessageTimeSpecification: (NSString*) timespec;

@end

#endif	/* __NSCalendarDate_NetExt_h_INCLUDE */

