/*
$Id: NSHost+GIReachability.m,v 1.3 2003/08/03 13:11:34 theisen Exp $

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
 at http://www.objectpark.org/Ginko.html
 */

#import "NSHost+GIReachability.h"
#import <SystemConfiguration/SystemConfiguration.h>

@implementation NSHost (GIReachability)
/*" Extension to %{NSHost} for checking is the host is directly usable at the moment.

Beware! NSHost is not thread-safe. So is this category. Lock in user code if needed."*/

- (BOOL)isReachableWithNoStringsAttached
/*" Returns YES, if the receiver's corresponding host is directly reachable at the moment. NO otherwise. "*/
{
    BOOL success, isReachable, noStringsAttached;
    SCNetworkConnectionFlags flags;

    success = SCNetworkCheckReachabilityByName([[self name] UTF8String], &flags);

    isReachable = (flags & kSCNetworkFlagsReachable) != 0;
    noStringsAttached = (flags & (kSCNetworkFlagsConnectionRequired | kSCNetworkFlagsInterventionRequired)) == 0;

    return success && isReachable && noStringsAttached;
}

@end
